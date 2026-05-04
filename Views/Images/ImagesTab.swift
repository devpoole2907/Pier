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
                .hostTitleMenu()
        }
    }
}

/// Resolves the active host then renders `ImagesListView`.
struct ImagesContainer: View {
    var body: some View {
        ActiveHostGate { host, client, endpointID in
            ImagesListView(client: client, endpointID: endpointID)
                .id(host.id)
        }
    }
}
