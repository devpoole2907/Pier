import SwiftUI
import SwiftData

/// Resolves the active host then renders the dashboard. Surfaced as a destination
/// within the More tab (see `MoreTab`).
struct StatsContainer: View {
    var body: some View {
        ActiveHostGate { host, client, endpointID in
            StatsDashboardView(client: client, endpointID: endpointID)
                .id(host.id)
        }
    }
}
