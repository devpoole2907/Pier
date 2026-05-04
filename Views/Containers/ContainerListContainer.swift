import SwiftUI
import SwiftData

/// Resolves the active host's `PortainerClient` from `HostManager`. If no host is active,
/// shows an "add a host" call-to-action instead of the list. Splitting this out from
/// `ContainerListView` lets the list itself assume a valid client exists.
struct ContainerListContainer: View {
    var body: some View {
        ActiveHostGate { host, client, endpointID in
            ContainerListView(client: client, endpointID: endpointID)
                .id(host.id)
        }
    }
}
