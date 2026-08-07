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
        .searchable(text: $viewModel.searchText, placement: .alwaysVisible, prompt: "Search logs")
        .task { await viewModel.loadInitial() }
        .onChange(of: viewModel.tailCount) {
            Task { await viewModel.reload() }
        }
        .onDisappear { viewModel.stopFollowing() }
        .sensoryFeedback(.success, trigger: copyFeedback)
    }

    @ToolbarContentBuilder
    private var logsToolbar: some ToolbarContent {
        ToolbarItem(placement: .platformTrailing) {
            Menu {
                Button(viewModel.isFollowing ? "Stop Live Tail" : "Start Live Tail",
                       systemImage: viewModel.isFollowing ? "stop.circle" : "dot.radiowaves.right",
                       action: toggleFollowing)

                Button("Copy", systemImage: "doc.on.doc", action: copyToClipboard)

                Divider()

                Menu {
                    Picker("Lines", selection: $viewModel.tailCount) {
                        ForEach(LogsViewModel.lineOptions, id: \.self) { count in
                            Text("\(count) lines").tag(count)
                        }
                    }
                } label: {
                    Label("Lines: \(viewModel.tailCount)", systemImage: "line.3.horizontal")
                }
            } label: {
                Label("Log options", systemImage: "ellipsis.circle")
            }
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
