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
        }
    }
}

/// Resolves the active host then renders the dashboard.
struct StatsContainer: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            StatsDashboardView(client: active.client, endpointID: active.endpointID)
                .id(active.host.id)
        } else {
            NoHostConfiguredView()
        }
    }
}
