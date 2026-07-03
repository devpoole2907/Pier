import SwiftUI

/// Owns a single Komodo terminal target's connection: one `KomodoTerminalConnection` (the
/// websocket transport) wired to one `SSHTerminalBridge` (the same bridge type SSH sessions use to
/// drive `SwiftTermView`). Mirrors `SSHSessionItem`'s wiring, just with a websocket instead of
/// libssh2 underneath.
@MainActor
@Observable
final class KomodoTerminalSession: Identifiable {
    let id = UUID()
    let host: Host
    let target: KomodoTerminalTarget
    let connection: KomodoTerminalConnection
    let bridge: SSHTerminalBridge
    var wantsKeyboard = false

    init(host: Host, target: KomodoTerminalTarget) {
        self.host = host
        self.target = target
        self.connection = KomodoTerminalConnection()
        self.bridge = SSHTerminalBridge()

        bridge.sendToSSH = { [connection] data in connection.send(data) }
        bridge.onResize = { [connection] cols, rows in connection.resize(cols: cols, rows: rows) }
        bridge.onKeyboardVisibilityChange = { [weak self] isVisible in
            self?.wantsKeyboard = isVisible
        }
        connection.onBytes = { [bridge] bytes in bridge.receive(bytes: bytes) }
    }

    func connectIfNeeded() async {
        switch connection.state {
        case .connected:
            wantsKeyboard = true
            return
        case .connecting:
            return
        case .failed, .closed:
            break
        }
        await connection.connect(host: host, target: target)
        if connection.state == .connected {
            wantsKeyboard = true
        }
    }

    func reconnect() async {
        wantsKeyboard = false
        connection.disconnect()
        await connection.connect(host: host, target: target)
        if connection.state == .connected {
            wantsKeyboard = true
        }
    }

    func disconnect() {
        wantsKeyboard = false
        bridge.hideKeyboard()
        connection.disconnect()
    }

    func hideKeyboard() {
        wantsKeyboard = false
        bridge.hideKeyboard()
    }
}

/// Live Komodo terminal, presented the same way an SSH session is (a large sheet). Renders the
/// same `SwiftTermView`/SwiftTerm emulator the SSH terminal uses, fed by `KomodoTerminalConnection`
/// over Komodo's `/ws/terminal` websocket instead of libssh2.
struct KomodoTerminalView: View {
    let host: Host
    let target: KomodoTerminalTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var session: KomodoTerminalSession

    init(host: Host, target: KomodoTerminalTarget) {
        self.host = host
        self.target = target
        self._session = State(initialValue: KomodoTerminalSession(host: host, target: target))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch session.connection.state {
                case .connecting:
                    connectingView
                case .connected:
                    terminalContent
                case .closed:
                    closedView
                case .failed(let message):
                    failedView(message: message)
                }
            }
            .navigationTitle(target.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        session.disconnect()
                        dismiss()
                    }
                }
            }
        }
        .task(id: session.id) {
            await session.connectIfNeeded()
        }
        .onDisappear {
            session.hideKeyboard()
        }
    }

    private var terminalContent: some View {
        SwiftTermView(
            bridge: session.bridge,
            wantsKeyboard: session.wantsKeyboard,
            colorScheme: colorScheme
        )
        .padding(6)
    }

    private var connectingView: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(DesignSystem.Colors.accent)
                    .controlSize(.large)
                Text(target.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var closedView: some View {
        ContentUnavailableView {
            Label("Session Closed", systemImage: target.kind.systemImage)
        } description: {
            Text("The terminal session has ended.")
        } actions: {
            Button("Reconnect") {
                Task { await session.reconnect() }
            }
        }
    }

    private func failedView(message: String) -> some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(.red.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                }
                VStack(spacing: 6) {
                    Text("Connection Failed")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(6)
                }
                Button {
                    Task { await session.reconnect() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.accent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    KomodoTerminalView(
        host: Host(name: "Home Server", baseURL: "https://10.0.0.5:9120"),
        target: KomodoTerminalTarget(kind: .container, resourceID: "abc", name: "nginx-proxy", subtitle: "my-server", serverID: "srv1")
    )
}
