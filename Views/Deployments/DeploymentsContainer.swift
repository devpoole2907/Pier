import SwiftUI

/// Entry point for the Deployments feature. Resolves the active Komodo host then renders the list.
/// Usable directly as a `MoreTab` destination - `MoreTab` supplies the navigation title, host title
/// menu, and server scope menu.
struct DeploymentsContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            DeploymentsListView(client: client)
                .id(host.id)
        }
    }
}
