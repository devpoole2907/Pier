import SwiftUI

/// Flat, searchable list of Komodo global variables. Read-only.
struct VariablesListView: View {
    @State private var viewModel: VariablesViewModel

    init(client: KomodoClient) {
        _viewModel = State(initialValue: VariablesViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading variables…")
            } else if let error = viewModel.loadError, viewModel.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.isEmpty {
                EmptyStateView(
                    title: "No variables",
                    systemImage: "curlybraces",
                    message: "Komodo has no global variables configured for this host."
                )
            } else if viewModel.hasNoSearchResults {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search variables")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var contentList: some View {
        List(viewModel.filteredVariables) { variable in
            VariableRowView(variable: variable)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .softScrollEdges()
    }
}
