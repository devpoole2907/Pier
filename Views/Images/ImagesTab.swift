import SwiftUI

/// Images tab root. `MoreTab` pushes `ImagesContainer` directly as a navigation destination, so
/// this standalone tab root isn't wired into any tab bar today, but is kept for parity with the
/// other feature "*Tab" roots and as a usable entry point if that changes.
struct ImagesTab: View {
    var body: some View {
        NavigationStack {
            ImagesContainer()
                .navigationTitle("Images")
                .serverScopeMenu()
        }
    }
}

/// Resolves the active host then renders `ImagesListView`, scoped to the active Komodo server
/// (`hostManager.activeServerID`, `nil` = "All servers", aggregated client-side by the view model).
/// `.scopedID` rebuilds the list - and its view model - whenever the active host or server changes.
struct ImagesContainer: View {
    @Environment(HostManager.self) private var hostManager

    var body: some View {
        ActiveHostGate { host, client in
            ImagesListView(client: client, serverID: hostManager.activeServerID, servers: hostManager.servers)
                .scopedID(host: host, serverID: hostManager.activeServerID)
        }
    }
}
