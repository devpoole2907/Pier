import SwiftUI
import SwiftData

/// Stats dashboard tab root.
struct StatsTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            StatsContainer()
                .navigationTitle("Stats")
                .navigationSubtitle(activeHostName)
                .hostTitleMenu()
        }
    }

    private var activeHostName: String {
        hostManager.activeClient(in: modelContext)?.host.name ?? ""
    }
}

/// Resolves the active host then renders the dashboard.
struct StatsContainer: View {
    var body: some View {
        ActiveHostGate { host, client, endpointID in
            StatsDashboardView(client: client, endpointID: endpointID)
                .id(host.id)
        }
    }
}
