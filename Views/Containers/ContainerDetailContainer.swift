import SwiftUI
import SwiftData

/// Bridges a navigation push (with just an ID) to the detail view (which needs a `PortainerClient`).
/// Resolves the active client from `HostManager` so the detail view itself can be unaware of where the
/// client comes from.
struct ContainerDetailContainer: View {
    let navigationValue: ContainerNavigationValue

    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            ContainerDetailView(
                client: active.client,
                endpointID: active.endpointID,
                containerID: navigationValue.containerID,
                initialName: navigationValue.displayName
            )
        } else {
            EmptyStateView(
                title: "No active host",
                systemImage: "externaldrive.badge.questionmark",
                message: "Select a Portainer host in Settings to continue."
            )
        }
    }
}
