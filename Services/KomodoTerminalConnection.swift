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
/// 1. Connect to `wss://<host>/ws/terminal?target[...]=...` (scheme swapped from the Core's
///    REST base URL, query string built manually to match `serde_qs` bracket notation).
/// 2. Send a `{"type":"ApiKeys","params":{"key":...,"secret":...}}` text frame and wait for the
///    literal text frame `"LOGGED_IN"`. Any other text before that is a login failure.
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

    private var session: URLSession?
    private var socketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var pendingSize: (cols: Int, rows: Int) = (80, 24)
    private var connectionToken = UUID()

    // MARK: - Connect

    func connect(host: Host, target: KomodoTerminalTarget) async {
        let token = UUID()
        connectionToken = token
        transition(.connecting)

        do {
            let url = try Self.buildURL(host: host, target: target)
            guard let apiKey = try KeychainService.apiKey(for: host.id), !apiKey.isEmpty,
                  let apiSecret = try KeychainService.apiSecret(for: host.id), !apiSecret.isEmpty else {
                throw KomodoTerminalConnectionError.missingCredentials
            }

            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = false
            let urlSession: URLSession = host.allowsInsecureTLS
                ? URLSession(configuration: config, delegate: InsecureTLSDelegate(), delegateQueue: nil)
                : URLSession(configuration: config)
            self.session = urlSession

            let webSocketTask = urlSession.webSocketTask(with: url)
            self.socketTask = webSocketTask
            webSocketTask.resume()

            try await sendLogin(task: webSocketTask, apiKey: apiKey, apiSecret: apiSecret)
            try await awaitLoggedIn(task: webSocketTask)
            guard connectionToken == token else { return }

            // Begin PTY output forwarding, then push the size we have (a default until the
            // terminal view reports its real size via `resize(cols:rows:)`).
            try await sendBegin(task: webSocketTask)
            try await sendResizeFrame(task: webSocketTask, cols: pendingSize.cols, rows: pendingSize.rows)
            guard connectionToken == token else { return }

            transition(.connected)
            startReceiveLoop(task: webSocketTask, token: token)
        } catch {
            guard connectionToken == token else { return }
            terminalLogger.error("Komodo terminal connection failed: \(error.localizedDescription, privacy: .private)")
            teardown()
            transition(.failed(error.localizedDescription))
        }
    }

    // MARK: - Send / Resize / Disconnect

    /// Forward raw stdin bytes to the server (`Forward` frame: bytes + trailing `0x01`).
    func send(_ data: Data) {
        guard let socketTask, state == .connected else { return }
        var payload = data
        payload.append(0x01)
        socketTask.send(.data(payload)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.handleTransportError(error)
            }
        }
    }

    /// Push a new terminal size (`Resize` frame: JSON + trailing `0xFF`). Safe to call before
    /// the connection is up — the latest size is remembered and used for the initial resize.
    func resize(cols: Int, rows: Int) {
        pendingSize = (cols, rows)
        guard let socketTask, state == .connected else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sendResizeFrame(task: socketTask, cols: cols, rows: rows)
            } catch {
                self.handleTransportError(error)
            }
        }
    }

    func disconnect() {
        guard state != .closed else { return }
        connectionToken = UUID()
        teardown()
        transition(.closed)
    }

    // MARK: - Handshake

    private struct LoginParams: Encodable {
        let key: String
        let secret: String
    }

    private struct LoginMessage: Encodable {
        let type = "ApiKeys"
        let params: LoginParams
    }

    private func sendLogin(task: URLSessionWebSocketTask, apiKey: String, apiSecret: String) async throws {
        let message = LoginMessage(params: LoginParams(key: apiKey, secret: apiSecret))
        let data = try JSONEncoder().encode(message)
        guard let json = String(data: data, encoding: .utf8) else {
            throw KomodoTerminalConnectionError.unexpectedResponse
        }
        try await task.send(.string(json))
    }

    private func awaitLoggedIn(task: URLSessionWebSocketTask) async throws {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            guard text == "LOGGED_IN" else {
                throw KomodoTerminalConnectionError.loginFailed(text)
            }
        case .data(let data):
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw KomodoTerminalConnectionError.loginFailed(text.isEmpty ? "Unexpected response before login." : text)
        @unknown default:
            throw KomodoTerminalConnectionError.unexpectedResponse
        }
    }

    private func sendBegin(task: URLSessionWebSocketTask) async throws {
        try await task.send(.data(Data([0x00])))
    }

    private struct ResizePayload: Encodable {
        let rows: Int
        let cols: Int
    }

    private func sendResizeFrame(task: URLSessionWebSocketTask, cols: Int, rows: Int) async throws {
        var payload = try JSONEncoder().encode(ResizePayload(rows: rows, cols: cols))
        payload.append(0xFF)
        try await task.send(.data(payload))
    }

    // MARK: - Receive loop

    private func startReceiveLoop(task: URLSessionWebSocketTask, token: UUID) {
        receiveLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard self.connectionToken == token else { return }
                    switch message {
                    case .data(let data):
                        self.onBytes?([UInt8](data))
                    case .string(let text):
                        self.onBytes?(Array(text.utf8))
                    @unknown default:
                        break
                    }
                } catch {
                    guard self.connectionToken == token else { return }
                    self.handleTransportError(error)
                    return
                }
            }
        }
    }

    private func handleTransportError(_ error: Error) {
        guard state != .closed else { return }
        teardown()
        transition(.failed(error.localizedDescription))
    }

    private func teardown() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func transition(_ newState: State) {
        guard state != newState else { return }
        state = newState
        onStateChange?(newState)
    }

    // MARK: - URL construction

    /// Builds the `/ws/terminal` websocket URL for a target: swaps the Core's REST scheme for
    /// `ws`/`wss`, and hand-builds the query string to match `serde_qs` bracket notation
    /// (`target[type]=...&target[params][...]=...`).
    ///
    /// Built via `URLComponents.queryItems` rather than string concatenation: Foundation's query
    /// percent-encoder correctly escapes `[`/`]` (invalid literal query characters per RFC 3986)
    /// without double-encoding values, which hand-rolled percent-encoding + `URL(string:)` does
    /// not reliably do on newer Foundation. Servers built on `serde_qs` percent-decode the whole
    /// query before parsing bracket syntax, so encoded brackets are equivalent to literal ones.
    static func buildURL(host: Host, target: KomodoTerminalTarget) throws -> URL {
        let trimmed = host.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawURL = URL(string: trimmed),
              var components = URLComponents(url: rawURL, resolvingAgainstBaseURL: false) else {
            throw KomodoTerminalConnectionError.invalidURL
        }

        switch components.scheme?.lowercased() {
        case "https": components.scheme = "wss"
        case "http": components.scheme = "ws"
        case "wss", "ws": break
        default: throw KomodoTerminalConnectionError.invalidURL
        }
        components.path = "/ws/terminal"
        components.queryItems = try queryItems(for: target)

        // URLQueryItem's encoder leaves '+' unescaped, which some server-side form decoders
        // interpret as a literal space. Escape it explicitly; every other '+' source (space,
        // brackets, etc.) is already percent-encoded, so this can't clash with anything else.
        if let query = components.percentEncodedQuery {
            components.percentEncodedQuery = query.replacingOccurrences(of: "+", with: "%2B")
        }

        guard let url = components.url else { throw KomodoTerminalConnectionError.invalidURL }
        return url
    }

    private static func queryItems(for target: KomodoTerminalTarget) throws -> [URLQueryItem] {
        var items: [URLQueryItem]
        switch target.kind {
        case .server:
            items = [
                URLQueryItem(name: "target[type]", value: "Server"),
                URLQueryItem(name: "target[params][server]", value: target.resourceID)
            ]
        case .container:
            guard let serverID = target.serverID, !serverID.isEmpty else {
                throw KomodoTerminalConnectionError.missingContext(
                    "This container target is missing its server and can't be opened."
                )
            }
            items = [
                URLQueryItem(name: "target[type]", value: "Container"),
                URLQueryItem(name: "target[params][server]", value: serverID),
                URLQueryItem(name: "target[params][container]", value: target.name),
                URLQueryItem(name: "init[command]", value: "sh"),
                URLQueryItem(name: "init[mode]", value: "exec")
            ]
        case .stack:
            items = [
                URLQueryItem(name: "target[type]", value: "Stack"),
                URLQueryItem(name: "target[params][stack]", value: target.resourceID),
                URLQueryItem(name: "target[params][service]", value: target.serviceName ?? "")
            ]
        case .deployment:
            items = [
                URLQueryItem(name: "target[type]", value: "Deployment"),
                URLQueryItem(name: "target[params][deployment]", value: target.resourceID)
            ]
        }
        items.append(URLQueryItem(name: "terminal", value: "pier"))
        return items
    }
}
