import SwiftUI
import SwiftData

/// Resolves the active host's `PortainerClient` from `HostManager`. If no host is active,
/// shows an "add a host" call-to-action instead of the list. Splitting this out from
/// `ContainerListView` lets the list itself assume a valid client exists.
struct ContainerListContainer: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            ContainerListView(client: active.client, endpointID: active.endpointID)
                .id(active.host.id)
        } else if hostManager.activeHostID != nil {
            // Active host selected but endpoint hasn't been resolved yet.
            LoadingView(message: "Connecting to host…")
        } else {
            NoHostConfiguredView()
        }
    }
}
