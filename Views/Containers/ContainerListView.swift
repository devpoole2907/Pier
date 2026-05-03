import SwiftUI

/// Main container list view. Orchestrates the view model, filter chips, search, and tap actions.
struct ContainerListView: View {
    @State private var viewModel: ContainerListViewModel
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalRaw: Int = RefreshInterval.medium.rawValue

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: ContainerListViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.containers.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading containers…")
            } else if let error = viewModel.loadError, viewModel.containers.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.containers.isEmpty {
                EmptyStateView(
                    title: "No containers",
                    systemImage: "shippingbox",
                    message: "This host has no Docker containers yet."
                )
            } else if viewModel.visibleContainers.isEmpty {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search containers")
        .refreshable { await viewModel.refresh() }
        .toolbar { filterToolbar }
        .task { await viewModel.load() }
        .task(id: refreshIntervalRaw) {
            guard let interval = RefreshInterval(rawValue: refreshIntervalRaw)?.seconds else { return }
            await viewModel.runPolling(every: interval)
        }
    }

    @ViewBuilder
    private var contentList: some View {
        if viewModel.filter == .byStack {
            ContainerListByStackView(viewModel: viewModel)
        } else {
            ContainerListFlatView(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: toolbarTrailingPlacement) {
            Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(ContainerFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
            }
        }
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
