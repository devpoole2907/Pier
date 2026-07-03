import SwiftUI

/// Entry point for the Procedures feature. Resolves the active Komodo host then renders the list.
/// Usable directly as a `MoreTab` destination.
struct ProceduresContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            ProceduresListView(client: client)
                .id(host.id)
        }
        .navigationTitle("Procedures")
    }
}
