import SwiftUI

/// Resolves the active host then renders the Dashboard overview. This is the top-level "at a
/// glance" surface for the whole app - see `DashboardView` for the card layout.
struct DashboardContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            DashboardView(client: client)
                .id(host.id)
        }
    }
}
