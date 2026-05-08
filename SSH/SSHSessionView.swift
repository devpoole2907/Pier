import SwiftData
import SwiftUI

struct SSHSessionView: View {
    let session: SSHSessionItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch session.connection.state {
            case .connecting:
                connectingView
            case .connected, .disconnected:
                terminalContent
            case .failed(let message):
                failedView(message: message)
            }
        }
        .alert("New Host Fingerprint", isPresented: Binding(
            get: { session.pendingFingerprint != nil },
            set: { if !$0 { session.confirmFingerprint(accepted: false) } }
        )) {
            Button("Trust & Connect") { session.confirmFingerprint(accepted: true) }
            Button("Cancel", role: .cancel) { session.confirmFingerprint(accepted: false) }
        } message: {
            if let fingerprint = session.pendingFingerprint {
                Text("The host is presenting a fingerprint that hasn't been seen before:\n\n\(fingerprint)\n\nDo you want to trust this host?")
            }
        }
        .task(id: session.id) {
            await session.connectIfNeeded(modelContext: modelContext)
        }
        .onAppear {
            if session.connection.state == .connected {
                session.focusSession()
            }
        }
        .onDisappear {
            session.wantsKeyboard = false
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
                    .tint(.green)
                    .controlSize(.large)
                Text(session.profile.hostDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
                Button {
                    Task { await session.reconnect(modelContext: modelContext) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.regular)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 32)
        }
    }
}
