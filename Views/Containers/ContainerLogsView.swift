import SwiftUI

/// Logs view. Tails 200 lines, with "Load more" and a follow toggle.
struct ContainerLogsView: View {
    @State private var viewModel: LogsViewModel
    @State private var copyFeedback = false

    init(client: PortainerClient, endpointID: Int, containerID: String) {
        _viewModel = State(initialValue: LogsViewModel(
            client: client,
            endpointID: endpointID,
            containerID: containerID
        ))
    }

    var body: some View {
        Group {
            if let error = viewModel.loadError, viewModel.lines.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.loadInitial() }
                }
            } else if viewModel.lines.isEmpty {
                LoadingView(message: "Fetching logs…")
            } else {
                LogsScrollView(viewModel: viewModel)
            }
        }
        .navigationTitle("Logs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { logsToolbar }
        .searchable(text: $viewModel.searchText, prompt: "Search logs")
        .task { await viewModel.loadInitial() }
        .onDisappear { viewModel.stopFollowing() }
        .sensoryFeedback(.success, trigger: copyFeedback)
    }

    @ToolbarContentBuilder
    private var logsToolbar: some ToolbarContent {
        ToolbarItem(placement: toolbarTrailingPlacement) {
            Button(viewModel.isFollowing ? "Stop following" : "Follow",
                   systemImage: viewModel.isFollowing ? "dot.radiowaves.left.and.right" : "dot.radiowaves.right",
                   action: toggleFollowing)
        }
        ToolbarItem(placement: toolbarTrailingPlacement) {
            Button("Copy", systemImage: "doc.on.doc", action: copyToClipboard)
        }
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    private func toggleFollowing() {
        if viewModel.isFollowing {
            viewModel.stopFollowing()
        } else {
            Task { await viewModel.startFollowing() }
        }
    }

    private func copyToClipboard() {
#if canImport(UIKit)
        UIPasteboard.general.string = viewModel.combinedText
#endif
        copyFeedback.toggle()
    }
}
