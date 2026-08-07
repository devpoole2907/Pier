import SwiftUI

/// Sectioned list of active and resolved Komodo alerts. Read-only.
struct AlertsListView: View {
    @State private var viewModel: AlertsViewModel

    init(client: KomodoClient) {
        _viewModel = State(initialValue: AlertsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading alerts…")
            } else if let error = viewModel.loadError, viewModel.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.isEmpty {
                EmptyStateView(
                    title: "No alerts",
                    systemImage: "bell.badge",
                    message: "Komodo hasn't raised any alerts for this host."
                )
            } else if viewModel.hasNoSearchResults {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .searchable(text: $viewModel.searchText, placement: .alwaysVisible, prompt: "Search alerts")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            if !viewModel.activeAlerts.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeAlerts) { alert in
                        AlertRowView(alert: alert)
                    }
                }
            }
            if !viewModel.resolvedAlerts.isEmpty {
                Section("Resolved") {
                    ForEach(viewModel.resolvedAlerts) { alert in
                        AlertRowView(alert: alert)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .softScrollEdges()
    }
}
