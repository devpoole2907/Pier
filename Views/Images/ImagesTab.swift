import SwiftUI
import SwiftData

/// Images tab root.
struct ImagesTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ImagesContainer()
                .navigationTitle("Images")
        }
    }
}

/// Resolves the active host then renders `ImagesListView`.
struct ImagesContainer: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            ImagesListView(client: active.client, endpointID: active.endpointID)
                .id(active.host.id)
        } else {
            NoHostConfiguredView()
        }
    }
}
