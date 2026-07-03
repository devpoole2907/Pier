import Foundation
import Network

/// A minimal RFC 6455 WebSocket client built directly on `NWConnection`.
///
/// Why not `URLSessionWebSocketTask`? Komodo Core parses the terminal endpoint's query with
/// `serde_qs`, which requires **literal** `[`/`]` bytes to parse nested keys like
/// `target[params][server]`. Foundation's `URL`/`URLComponents` refuse to carry literal brackets —
/// they percent-encode them to `%5B`/`%5D` (or fatal-error), and serde_qs then reads the encoded
/// key as a single flat name and rejects the request with HTTP 400. `URLSessionWebSocketTask` only
/// accepts a `URL`, so it can never send what Komodo needs. Here we write the HTTP upgrade
/// request line ourselves, so the request-target keeps its literal brackets.
///
/// Scope: this implements exactly what the Komodo terminal protocol uses — a client handshake,
/// masked text/binary frames out, unmasked text/binary/ping/close frames in, and message
/// reassembly across continuation frames. It is not a general-purpose WebSocket library.
final class KomodoWebSocketChannel {
    enum ChannelError: LocalizedError {
        case handshakeRejected(status: Int, reason: String)
        case handshakeMalformed
        case connectionFailed(String)
        case closed

        var errorDescription: String? {
            switch self {
            case .handshakeRejected(let status, let reason):
                "Server rejected the terminal connection: HTTP \(status) \(reason)."
            case .handshakeMalformed:
                "The server's terminal handshake response was malformed."
            case .connectionFailed(let message):
                message
            case .closed:
                "The terminal connection closed."
            }
        }
    }

    /// Called once the HTTP upgrade succeeds (HTTP 101) and the socket is ready for frames.
    var onOpen: (() -> Void)?
    var onText: ((String) -> Void)?
    var onBinary: ((Data) -> Void)?
    /// A handshake or transport error. Terminal — no further callbacks follow.
    var onFailure: ((Error) -> Void)?
    /// A clean close initiated by the server. Terminal.
    var onClose: (() -> Void)?

    private let host: String
    private let port: UInt16
    private let useTLS: Bool
    private let requestTarget: String
    private let hostHeader: String
    private let allowsInsecureTLS: Bool

    private let queue = DispatchQueue(label: "com.poole.james.pier.komodo-ws")
    private var connection: NWConnection?

    /// Bytes received but not yet consumed (HTTP headers first, then frame data).
    private var inbound: [UInt8] = []
    private var handshakeComplete = false
    private var isFinished = false

    /// Reassembly state for fragmented messages (continuation frames).
    private var fragmentOpcode: UInt8?
    private var fragmentPayload: [UInt8] = []

    init(host: String, port: UInt16, useTLS: Bool, requestTarget: String, hostHeader: String, allowsInsecureTLS: Bool) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.requestTarget = requestTarget
        self.hostHeader = hostHeader
        self.allowsInsecureTLS = allowsInsecureTLS
    }

    // MARK: - Lifecycle

    func connect() {
        let parameters: NWParameters
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            if allowsInsecureTLS {
                sec_protocol_options_set_verify_block(
                    tlsOptions.securityProtocolOptions,
                    { _, _, complete in complete(true) },
                    queue
                )
            }
            parameters = NWParameters(tls: tlsOptions)
        } else {
            parameters = NWParameters(tls: nil)
        }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            fail(ChannelError.connectionFailed("Invalid port \(port)."))
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendHandshake()
                self.receiveLoop()
            case .failed(let error):
                self.fail(ChannelError.connectionFailed(error.localizedDescription))
            case .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self, !self.isFinished else { return }
            self.isFinished = true
            self.connection?.cancel()
            self.connection = nil
        }
    }

    // MARK: - Sending

    func sendText(_ string: String) {
        send(opcode: 0x1, payload: Data(string.utf8))
    }

    func sendBinary(_ data: Data) {
        send(opcode: 0x2, payload: data)
    }

    private func send(opcode: UInt8, payload: Data) {
        queue.async { [weak self] in
            guard let self, let connection = self.connection, !self.isFinished else { return }
            let frame = Self.encodeClientFrame(opcode: opcode, payload: payload)
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.fail(ChannelError.connectionFailed(error.localizedDescription))
                }
            })
        }
    }

    // MARK: - Handshake

    private func sendHandshake() {
        var request = "GET \(requestTarget) HTTP/1.1\r\n"
        request += "Host: \(hostHeader)\r\n"
        request += "Upgrade: websocket\r\n"
        request += "Connection: Upgrade\r\n"
        request += "Sec-WebSocket-Key: \(Self.makeWebSocketKey())\r\n"
        request += "Sec-WebSocket-Version: 13\r\n"
        request += "\r\n"

        connection?.send(content: Data(request.utf8), completion: .contentProcessed { [weak self] error in
            if let error {
                self?.fail(ChannelError.connectionFailed(error.localizedDescription))
            }
        })
    }

    private static func makeWebSocketKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }

    // MARK: - Receiving

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, !self.isFinished else { return }
            if let error {
                self.fail(ChannelError.connectionFailed(error.localizedDescription))
                return
            }
            if let data, !data.isEmpty {
                self.inbound.append(contentsOf: data)
                self.drainInbound()
            }
            if isComplete {
                self.finishWithClose()
                return
            }
            if !self.isFinished {
                self.receiveLoop()
            }
        }
    }

    private func drainInbound() {
        if !handshakeComplete {
            guard consumeHandshake() else { return }
        }
        parseFrames()
    }

    /// Parses the HTTP upgrade response from the front of `inbound`. Returns true once the full
    /// header block has been consumed and the handshake succeeded (leaving any trailing frame bytes
    /// in `inbound`); false if more bytes are still needed. Fails the channel on a non-101 status.
    private func consumeHandshake() -> Bool {
        let terminator: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
        guard let range = firstRange(of: terminator, in: inbound) else { return false }

        let headerBytes = Array(inbound[0..<range.lowerBound])
        inbound.removeSubrange(0..<range.upperBound)

        let header = String(decoding: headerBytes, as: UTF8.self)
        guard let statusLine = header.split(separator: "\r\n").first else {
            fail(ChannelError.handshakeMalformed)
            return false
        }

        // "HTTP/1.1 101 Switching Protocols"
        let parts = statusLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2, let status = Int(parts[1]) else {
            fail(ChannelError.handshakeMalformed)
            return false
        }
        guard status == 101 else {
            let reason = parts.count >= 3 ? String(parts[2]) : HTTPURLResponse.localizedString(forStatusCode: status)
            fail(ChannelError.handshakeRejected(status: status, reason: reason))
            return false
        }

        handshakeComplete = true
        emit { $0.onOpen?() }
        return true
    }

    // MARK: - Frame parsing

    private func parseFrames() {
        while true {
            guard inbound.count >= 2 else { return }
            let byte0 = inbound[0]
            let byte1 = inbound[1]
            let fin = (byte0 & 0x80) != 0
            let opcode = byte0 & 0x0F
            let masked = (byte1 & 0x80) != 0
            var payloadLength = Int(byte1 & 0x7F)
            var offset = 2

            if payloadLength == 126 {
                guard inbound.count >= offset + 2 else { return }
                payloadLength = Int(inbound[offset]) << 8 | Int(inbound[offset + 1])
                offset += 2
            } else if payloadLength == 127 {
                guard inbound.count >= offset + 8 else { return }
                var length = 0
                for index in 0..<8 { length = (length << 8) | Int(inbound[offset + index]) }
                payloadLength = length
                offset += 8
            }

            var maskKey: [UInt8] = []
            if masked {
                guard inbound.count >= offset + 4 else { return }
                maskKey = Array(inbound[offset..<offset + 4])
                offset += 4
            }

            guard inbound.count >= offset + payloadLength else { return }
            var payload = Array(inbound[offset..<offset + payloadLength])
            if masked {
                for index in payload.indices { payload[index] ^= maskKey[index % 4] }
            }
            inbound.removeSubrange(0..<offset + payloadLength)

            handleFrame(fin: fin, opcode: opcode, payload: payload)
            if isFinished { return }
        }
    }

    private func handleFrame(fin: Bool, opcode: UInt8, payload: [UInt8]) {
        switch opcode {
        case 0x0: // continuation
            fragmentPayload.append(contentsOf: payload)
            if fin, let assembledOpcode = fragmentOpcode {
                let assembled = fragmentPayload
                fragmentOpcode = nil
                fragmentPayload = []
                deliverMessage(opcode: assembledOpcode, payload: assembled)
            }
        case 0x1, 0x2: // text / binary
            if fin {
                deliverMessage(opcode: opcode, payload: payload)
            } else {
                fragmentOpcode = opcode
                fragmentPayload = payload
            }
        case 0x8: // close
            finishWithClose()
        case 0x9: // ping -> pong
            send(opcode: 0xA, payload: Data(payload))
        case 0xA: // pong
            break
        default:
            break
        }
    }

    private func deliverMessage(opcode: UInt8, payload: [UInt8]) {
        switch opcode {
        case 0x1:
            let text = String(decoding: payload, as: UTF8.self)
            emit { $0.onText?(text) }
        case 0x2:
            let data = Data(payload)
            emit { $0.onBinary?(data) }
        default:
            break
        }
    }

    // MARK: - Termination

    private func fail(_ error: Error) {
        guard !isFinished else { return }
        isFinished = true
        connection?.cancel()
        connection = nil
        emit { $0.onFailure?(error) }
    }

    private func finishWithClose() {
        guard !isFinished else { return }
        isFinished = true
        connection?.cancel()
        connection = nil
        emit { $0.onClose?() }
    }

    /// Callbacks are delivered on the main actor so `KomodoTerminalConnection` (a `@MainActor`
    /// observable) can touch its state directly.
    private func emit(_ body: @escaping (KomodoWebSocketChannel) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            body(self)
        }
    }

    // MARK: - Encoding helpers

    private static func encodeClientFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(0x80 | opcode) // FIN + opcode

        let length = payload.count
        let maskBit: UInt8 = 0x80
        if length < 126 {
            frame.append(maskBit | UInt8(length))
        } else if length <= 0xFFFF {
            frame.append(maskBit | 126)
            frame.append(UInt8((length >> 8) & 0xFF))
            frame.append(UInt8(length & 0xFF))
        } else {
            frame.append(maskBit | 127)
            let value = UInt64(length)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((value >> UInt64(shift)) & 0xFF))
            }
        }

        var maskKey = [UInt8](repeating: 0, count: 4)
        for index in maskKey.indices { maskKey[index] = UInt8.random(in: 0...255) }
        frame.append(contentsOf: maskKey)

        var masked = [UInt8](payload)
        for index in masked.indices { masked[index] ^= maskKey[index % 4] }
        frame.append(contentsOf: masked)

        return frame
    }

    private func firstRange(of pattern: [UInt8], in bytes: [UInt8]) -> Range<Int>? {
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return nil }
        let upperBound = bytes.count - pattern.count
        var start = 0
        while start <= upperBound {
            if Array(bytes[start..<start + pattern.count]) == pattern {
                return start..<(start + pattern.count)
            }
            start += 1
        }
        return nil
    }
}
