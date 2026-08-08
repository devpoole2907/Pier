import SwiftUI

/// Shown when no Komodo Core is configured. Acts as the empty state for any tab.
struct NoHostConfiguredView: View {
    @Environment(HostManager.self) private var hostManager

    var body: some View {
        ContentUnavailableView {
            Label("Komodo isn’t connected", systemImage: "externaldrive.badge.questionmark")
        } description: {
            Text("Connect your Komodo Core to start managing its servers and containers.")
        } actions: {
            Button("Connect Komodo", systemImage: "link") {
                hostManager.editingHost = nil
                hostManager.isPresentingHostEditor = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    NoHostConfiguredView()
        .environment(HostManager())
}
