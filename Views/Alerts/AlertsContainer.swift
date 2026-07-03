import SwiftUI

/// Entry point for the Alerts feature. Resolves the active Komodo host then renders the list.
/// Usable directly as a `MoreTab` destination.
struct AlertsContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            AlertsListView(client: client)
                .id(host.id)
        }
        .navigationTitle("Alerts")
    }
}
