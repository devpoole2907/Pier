import SwiftUI

/// Logs view. Tails 200 lines, with "Load more" and a follow toggle. "Follow" is polling-based
/// (Komodo has no log-stream endpoint) - see `LogsViewModel` for details.
struct ContainerLogsView: View {
    @State private var viewModel: LogsViewModel
    @State private var copyFeedback = false

    init(client: KomodoClient, serverID: String, containerID: String) {
        _viewModel = State(initialValue: LogsViewModel(
            client: client,
            serverID: serverID,
            containerID: containerID
        ))
    }

    var body: some View {
        Group {
            if let error = viewModel.loadError, viewModel.lines.isEmpty {
                ErrorView(error: error, retry: {
                    Task { await viewModel.loadInitial() }
                })
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
        ToolbarItem(placement: .platformTrailing) {
            Button(viewModel.isFollowing ? "Stop Live Tail" : "Start Live Tail",
                   systemImage: viewModel.isFollowing ? "dot.radiowaves.left.and.right" : "dot.radiowaves.right",
                   action: toggleFollowing)
                .help(viewModel.isFollowing ? "Stop streaming new log lines as they arrive." : "Start streaming new log lines as they arrive.")
        }
        ToolbarItem(placement: .platformTrailing) {
            Button("Copy", systemImage: "doc.on.doc", action: copyToClipboard)
        }
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
