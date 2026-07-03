import SwiftUI
import SwiftData

/// Resolves the active host's `KomodoClient` from `HostManager`. If no host is active,
/// shows an "add a host" call-to-action instead of the list. Splitting this out from
/// `ContainerListView` lets the list itself assume a valid client exists.
///
/// Scopes the list by `hostManager.activeServerID` (Komodo's first-class Servers concept) - `nil`
/// means "All servers". `.scopedID` rebuilds the view (and its view model) whenever either the
/// active host or the active server scope changes.
struct ContainerListContainer: View {
    @Environment(HostManager.self) private var hostManager

    var body: some View {
        ActiveHostGate { host, client in
            ContainerListView(client: client, serverID: hostManager.activeServerID)
                .scopedID(host: host, serverID: hostManager.activeServerID)
        }
    }
}
