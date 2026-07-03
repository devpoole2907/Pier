import Foundation
import OSLog

private let terminalLogger = Logger(subsystem: "com.poole.james.pier", category: "komodo-terminal")

/// Errors surfaced while building or running a Komodo terminal websocket connection.
enum KomodoTerminalConnectionError: LocalizedError {
    case invalidURL
    case missingCredentials
    case missingContext(String)
    case loginFailed(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Could not build a terminal URL for this host."
        case .missingCredentials:
            "This host has no API key/secret configured. Add them in the host's settings."
        case .missingContext(let message):
            message
        case .loginFailed(let message):
            "Login failed: \(message)"
        case .unexpectedResponse:
            "Unexpected response from the terminal server."
        }
    }
}

/// Drives a single live terminal session against Komodo Core's websocket terminal endpoint
/// (`/ws/terminal`), reusing the exact wire protocol Komodo's own web UI speaks:
///
/// 1. Connect to `wss://<host>/ws/terminal?target[...]=...`. The query keeps **literal** brackets:
///    Komodo parses it with `serde_qs`, which only recognises nested keys written with real
///    `[`/`]` bytes — percent-encoded `%5B`/`%5D` are read as a flat key and rejected (HTTP 400).
///    Because Foundation's `URL` can't carry literal brackets, the transport is a hand-rolled
///    WebSocket over `NWConnection` (`KomodoWebSocketChannel`) rather than `URLSessionWebSocketTask`.
/// 2. Send a `{"type":"ApiKeys","params":{"key":...,"secret":...}}` text frame and wait for the
///    literal text frame `"LOGGED_IN"`. Any other text (e.g. `"ERROR: ..."`) is a login failure.
/// 3. Send a `Begin` binary frame (single `0x00` byte) to start PTY output forwarding, then an
///    initial `Resize` frame.
/// 4. From then on, binary (occasionally text) frames from the server are raw PTY stdout bytes;
///    stdin bytes are sent as binary frames with a trailing variant byte (`Forward` = bytes +
///    `0x01`, `Resize` = JSON + `0xFF`).
///
/// This class only speaks the websocket protocol — the actual terminal emulation is SwiftTerm,
/// driven the same way `SSHConnection` drives it for SSH sessions (see `SSHTerminalBridge`).
@MainActor
@Observable
final class KomodoTerminalConnection {
    enum State: Equatable {
        case connecting
        case connected
        case failed(String)
        case closed
    }

    private(set) var state: State = .closed

    /// Raw PTY stdout bytes, ready to feed straight into `SSHTerminalBridge.receive(bytes:)`.
    var onBytes: (([UInt8]) -> Void)?
    var onStateChange: ((State) -> Void)?

    private var channel: KomodoWebSocketChannel?
    private var loginContinuation: CheckedContinuation<Void, Error>?
    private var pendingSize: (cols: Int, rows: Int) = (80, 24)
    private var connectionToken = UUID()

    // MARK: - Connect

    func connect(host: Host, target: KomodoTerminalTarget) async {
        let token = UUID()
        connectionToken = token
        transition(.connecting)

        do {
            let request = try Self.buildRequest(host: host, target: target)
            guard let apiKey = try KeychainService.apiKey(for: host.id), !apiKey.isEmpty,
                  let apiSecret = try KeychainService.apiSecret(for: host.id), !apiSecret.isEmpty else {
                throw KomodoTerminalConnectionError.missingCredentials
            }
            let loginJSON = try Self.loginJSON(apiKey: apiKey, apiSecret: apiSecret)

            let channel = KomodoWebSocketChannel(
                host: request.host,
                port: request.port,
                useTLS: request.useTLS,
                requestTarget: request.requestTarget,
                hostHeader: request.hostHeader,
                allowsInsecureTLS: host.allowsInsecureTLS
            )
            self.channel = channel

            // Phase 1: connect + log in. The continuation resumes on "LOGGED_IN" (success) or on
            // the first failure/close/non-login text.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.loginContinuation = continuation
                channel.onOpen = { [weak channel] in channel?.sendText(loginJSON) }
                channel.onText = { [weak self] text in self?.handleLoginText(text) }
                channel.onBinary = { _ in }
                channel.onFailure = { [weak self] error in self?.resumeLogin(throwing: error) }
                channel.onClose = { [weak self] in
                    self?.resumeLogin(throwing: KomodoTerminalConnectionError.loginFailed("Connection closed before login completed."))
                }
                channel.connect()
            }
            guard connectionToken == token else { channel.cancel(); return }

            // Phase 2: streaming. Reroute frames to the terminal bridge.
            channel.onText = { [weak self] text in self?.onBytes?(Array(text.utf8)) }
            channel.onBinary = { [weak self] data in self?.onBytes?([UInt8](data)) }
            channel.onFailure = { [weak self] error in self?.handleTransportError(error) }
            channel.onClose = { [weak self] in self?.handleServerClose() }

            channel.sendBinary(Data([0x00])) // Begin
            channel.sendBinary(try Self.resizeFrameData(cols: pendingSize.cols, rows: pendingSize.rows))
            guard connectionToken == token else { channel.cancel(); return }

            transition(.connected)
        } catch {
            guard connectionToken == token else { return }
            let message = Self.message(for: error)
            terminalLogger.error("Komodo terminal connection failed: \(message, privacy: .private)")
            teardown()
            transition(.failed(message))
        }
    }

    // MARK: - Send / Resize / Disconnect

    /// Forward raw stdin bytes to the server (`Forward` frame: bytes + trailing `0x01`).
    func send(_ data: Data) {
        guard let channel, state == .connected else { return }
        var payload = data
        payload.append(0x01)
        channel.sendBinary(payload)
    }

    /// Push a new terminal size (`Resize` frame: JSON + trailing `0xFF`). Safe to call before
    /// the connection is up — the latest size is remembered and used for the initial resize.
    func resize(cols: Int, rows: Int) {
        pendingSize = (cols, rows)
        guard let channel, state == .connected else { return }
        guard let frame = try? Self.resizeFrameData(cols: cols, rows: rows) else { return }
        channel.sendBinary(frame)
    }

    func disconnect() {
        guard state != .closed else { return }
        connectionToken = UUID()
        teardown()
        transition(.closed)
    }

    // MARK: - Login handling

    private func handleLoginText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "LOGGED_IN" {
            resumeLogin(throwing: nil)
        } else {
            let detail = trimmed.hasPrefix("ERROR:")
                ? String(trimmed.dropFirst("ERROR:".count)).trimmingCharacters(in: .whitespaces)
                : trimmed
            resumeLogin(throwing: KomodoTerminalConnectionError.loginFailed(detail.isEmpty ? "Unexpected response before login." : detail))
        }
    }

    private func resumeLogin(throwing error: Error?) {
        guard let continuation = loginContinuation else { return }
        loginContinuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    // MARK: - Transport events

    private func handleTransportError(_ error: Error) {
        guard state == .connected || state == .connecting else { return }
        teardown()
        transition(.failed(Self.message(for: error)))
    }

    private func handleServerClose() {
        guard state == .connected else { return }
        teardown()
        transition(.closed)
    }

    private func teardown() {
        resumeLogin(throwing: KomodoTerminalConnectionError.loginFailed("Connection torn down."))
        channel?.cancel()
        channel = nil
    }

    private func transition(_ newState: State) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Frame encoding

    private struct LoginParams: Encodable {
        let key: String
        let secret: String
    }

    private struct LoginMessage: Encodable {
        let type = "ApiKeys"
        let params: LoginParams
    }

    private static func loginJSON(apiKey: String, apiSecret: String) throws -> String {
        let message = LoginMessage(params: LoginParams(key: apiKey, secret: apiSecret))
        let data = try JSONEncoder().encode(message)
        guard let json = String(data: data, encoding: .utf8) else {
            throw KomodoTerminalConnectionError.unexpectedResponse
        }
        return json
    }

    private struct ResizePayload: Encodable {
        let rows: Int
        let cols: Int
    }

    private static func resizeFrameData(cols: Int, rows: Int) throws -> Data {
        var payload = try JSONEncoder().encode(ResizePayload(rows: rows, cols: cols))
        payload.append(0xFF)
        return payload
    }

    // MARK: - Request construction

    /// The pieces needed to open the raw WebSocket: where to connect and the exact request-target
    /// (path + query) to write on the wire, with literal `serde_qs` brackets intact.
    struct Request {
        let host: String
        let port: UInt16
        let useTLS: Bool
        let requestTarget: String
        let hostHeader: String
    }

    /// RFC 3986 unreserved characters — the only bytes left un-percent-encoded in query *values*.
    /// Keys keep their literal brackets (never encoded), matching how Komodo's web UI builds the URL.
    private static let unreservedValueCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func buildRequest(host: Host, target: KomodoTerminalTarget) throws -> Request {
        let trimmed = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let hostName = components.host else {
            throw KomodoTerminalConnectionError.invalidURL
        }

        let scheme = components.scheme?.lowercased()
        let useTLS = scheme == "https" || scheme == "wss"
        let port = UInt16(components.port ?? (useTLS ? 443 : 80))
        let hostHeader = components.port.map { "\(hostName):\($0)" } ?? hostName

        let query = try queryString(for: target)
        return Request(
            host: hostName,
            port: port,
            useTLS: useTLS,
            requestTarget: "/ws/terminal?\(query)",
            hostHeader: hostHeader
        )
    }

    /// Builds the raw query string with literal brackets in the keys and percent-encoded values.
    private static func queryString(for target: KomodoTerminalTarget) throws -> String {
        var pairs: [(String, String)]
        switch target.kind {
        case .server:
            pairs = [
                ("target[type]", "Server"),
                ("target[params][server]", target.resourceID)
            ]
        case .container:
            guard let serverID = target.serverID, !serverID.isEmpty else {
                throw KomodoTerminalConnectionError.missingContext(
                    "This container target is missing its server and can't be opened."
                )
            }
            pairs = [
                ("target[type]", "Container"),
                ("target[params][server]", serverID),
                ("target[params][container]", target.name),
                ("init[command]", "sh"),
                ("init[mode]", "exec")
            ]
        case .stack:
            pairs = [
                ("target[type]", "Stack"),
                ("target[params][stack]", target.resourceID),
                ("target[params][service]", target.serviceName ?? "")
            ]
        case .deployment:
            pairs = [
                ("target[type]", "Deployment"),
                ("target[params][deployment]", target.resourceID)
            ]
        }
        pairs.append(("terminal", "pier"))

        return pairs.map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: unreservedValueCharacters) ?? value
            return "\(key)=\(encodedValue)"
        }.joined(separator: "&")
    }
}
