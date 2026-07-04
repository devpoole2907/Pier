import SwiftUI

/// The top-level Dashboard: a vertically-scrolling stack of self-contained per-service sections.
/// Today there is only `ServersSection` (Komodo host health), but the layout exists precisely so
/// later services get their own section added to the `LazyVStack` below without touching this
/// one - each section owns its own cards, its own empty/loading affordances for anything it
/// fetches beyond what `DashboardViewModel.load()` already covers, and reads only the slice of
/// the view model it needs.
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(client: KomodoClient) {
        _viewModel = State(initialValue: DashboardViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.servers.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading dashboard…")
            } else if let error = viewModel.loadError, viewModel.servers.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.servers.isEmpty {
                EmptyStateView(
                    title: "No servers",
                    systemImage: "server.rack",
                    message: "Servers connected to this Komodo Core will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xLarge) {
                        ServersSection(viewModel: viewModel)
                        // Future sections (Proxy/NPM, SSH, …) get added here, each as its own
                        // self-contained `View` reading its own view model.
                    }
                    .padding(DesignSystem.Spacing.large)
                }
                .background(Color.groupedListBackground)
                .softScrollEdges()
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}
