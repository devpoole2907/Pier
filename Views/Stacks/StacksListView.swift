import SwiftUI

/// Top-level list of Portainer-managed compose stacks.
struct StacksListView: View {
    @State private var viewModel: StacksViewModel

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: StacksViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.stacks.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading stacks…")
            } else if let error = viewModel.loadError, viewModel.stacks.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.stacks.isEmpty {
                EmptyStateView(
                    title: "No stacks",
                    systemImage: "square.stack.3d.up",
                    message: "Compose stacks managed by Portainer will appear here."
                )
            } else {
                List(viewModel.stacks) { stack in
                    NavigationLink(value: stack) {
                        StackRowView(stack: stack)
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}
