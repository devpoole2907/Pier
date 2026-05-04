import SwiftUI

/// Shown when there are no Portainer hosts saved. Acts as the empty state for any tab.
struct NoHostConfiguredView: View {
    @Environment(HostManager.self) private var hostManager

    var body: some View {
        ContentUnavailableView {
            Label("No Portainer host", systemImage: "externaldrive.badge.questionmark")
        } description: {
            Text("Add a Portainer instance to start managing containers.")
        } actions: {
            Button("Add Host", systemImage: "plus") {
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
