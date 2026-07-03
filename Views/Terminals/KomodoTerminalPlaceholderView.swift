import SwiftUI

/// Placeholder shown when opening a Komodo terminal target. The real terminal connection is not
/// implemented yet — this view only exists to scaffold the UI/UX flow (picking a target and
/// presenting a session sheet for it).
///
/// Intended follow-up implementation: reuse **SwiftTerm** (already driving `SSHTerminalView` for
/// SSH sessions) as the terminal emulator, fed by Komodo's websocket terminal endpoint
/// (Core exposes a per-server/container `/ws/.../terminal`-style stream) via
/// `URLSessionWebSocketTask`. That would mean building a `KomodoTerminalConnection` analogous to
/// `SSHConnection` that bridges websocket frames to/from the SwiftTerm view, and a session store
/// analogous to `SSHSessionStore` to manage lifecycle/background behaviour. None of that transport
/// work is done here.
struct KomodoTerminalPlaceholderView: View {
    let target: KomodoTerminalTarget

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(target.name, systemImage: target.kind.systemImage)
            } description: {
                Text("Komodo terminals coming soon")
            }
            .navigationTitle(target.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    KomodoTerminalPlaceholderView(
        target: KomodoTerminalTarget(kind: .container, resourceID: "abc", name: "nginx-proxy", subtitle: "my-server")
    )
}
