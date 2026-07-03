import SwiftUI

/// The "Servers" section of the Dashboard - Komodo host health at a glance. Grouped as a section
/// (title + a stack of cards) rather than one monolithic view, so a later section for another
/// Pier service (Proxy/NPM, SSH, …) can sit alongside it in `DashboardView` using the same shape:
/// a title, a summary card, and whatever detail cards make sense for that service.
struct ServersSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Label("Servers", systemImage: "server.rack")
                .font(.title3.weight(.semibold))

            ServersSummaryCard(viewModel: viewModel)
            ServersHistoryCard(viewModel: viewModel)
        }
    }
}
