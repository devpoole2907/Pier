import SwiftUI

struct StreamListView: View {
    @State private var viewModel: NPMStreamsViewModel
    @State private var showEditor = false
    @State private var editingStream: NPMStream?

    init(client: NPMClient) {
        _viewModel = State(initialValue: NPMStreamsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading streams…")
            } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("No streams", systemImage: "arrow.left.arrow.right")
                } description: {
                    Text("Create a TCP/UDP stream forward.")
                } actions: {
                    Button("Add stream", systemImage: "plus") {
                        editingStream = nil
                        showEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.visibleItems.isEmpty {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .navigationTitle("Streams")
        .searchable(text: $viewModel.searchText, prompt: "Search streams")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add", systemImage: "plus") {
                    editingStream = nil
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                StreamEditorView(viewModel: viewModel, existing: editingStream)
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(viewModel.visibleItems) { stream in
                Button {
                    editingStream = stream
                    showEditor = true
                } label: {
                    StreamRowView(stream: stream, actionState: viewModel.actionState(for: stream.id))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                        if viewModel.actionState(for: stream.id) == nil {
                            if stream.enabled?.boolValue ?? true {
                                Button("Disable", systemImage: "stop.circle") {
                                    Task { await viewModel.setEnabled(stream.id, enabled: false) }
                                }
                                .tint(.orange)
                            } else {
                                Button("Enable", systemImage: "play.circle") {
                                    Task { await viewModel.setEnabled(stream.id, enabled: true) }
                                }
                                .tint(.green)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(stream.id) }
                            }
                        }
                    }
                    .contextMenu {
                        if viewModel.actionState(for: stream.id) == nil {
                            if stream.enabled?.boolValue ?? true {
                                Button("Disable", systemImage: "stop.circle") {
                                    Task { await viewModel.setEnabled(stream.id, enabled: false) }
                                }
                            } else {
                                Button("Enable", systemImage: "play.circle") {
                                    Task { await viewModel.setEnabled(stream.id, enabled: true) }
                                }
                            }
                            Button("Edit", systemImage: "pencil") {
                                editingStream = stream
                                showEditor = true
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(stream.id) }
                            }
                        }
                    }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .scrollContentBackground(.hidden)
        .background(ProxyDestinationGradientBackground(accent: .stream))
    }
}
