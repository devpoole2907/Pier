import SwiftUI

/// Entry point for the Variables feature. Resolves the active Komodo host then renders the list.
/// Usable directly as a `MoreTab` destination.
struct VariablesContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            VariablesListView(client: client)
                .id(host.id)
        }
        .navigationTitle("Variables")
    }
}
