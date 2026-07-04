import SwiftUI
import SwiftData

/// Bridges a navigation push (with just an ID + server ID) to the detail view (which needs a
/// `KomodoClient`). Resolves the active client from `HostManager` so the detail view itself can
/// be unaware of where the client comes from.
struct ContainerDetailContainer: View {
    let navigationValue: ContainerNavigationValue

    var body: some View {
        ActiveHostGate { host, client in
            ContainerDetailView(
                client: client,
                hostID: host.id,
                serverID: navigationValue.serverID,
                containerID: navigationValue.containerID,
                initialName: navigationValue.displayName
            )
        }
    }
}
