import SwiftUI

struct RedirectionHostListView: View {
    @State private var viewModel: NPMRedirectionHostsViewModel
    @State private var isAddingHost = false
    @State private var editingHost: NPMRedirectionHost?

    init(client: NPMClient) {
        _viewModel = State(initialValue: NPMRedirectionHostsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading redirection hosts…")
            } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("No redirection hosts", systemImage: "arrow.triangle.turn.up.right.diamond")
                } description: {
                    Text("Create a redirect rule to get started.")
                } actions: {
                    Button("Add redirect", systemImage: "plus") {
                        editingHost = nil
                        isAddingHost = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.visibleItems.isEmpty {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .navigationTitle("Redirections")
        .searchable(text: $viewModel.searchText, prompt: "Search domains")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add", systemImage: "plus") {
                    editingHost = nil
                    isAddingHost = true
                }
            }
        }
        .sheet(isPresented: $isAddingHost) {
            NavigationStack {
                RedirectionHostEditorView(
                    viewModel: viewModel,
                    existing: nil
                )
            }
        }
        .sheet(item: $editingHost) { host in
            NavigationStack {
                RedirectionHostEditorView(
                    viewModel: viewModel,
                    existing: host
                )
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(viewModel.visibleItems) { host in
                Button {
                    editingHost = host
                } label: {
                    RedirectionHostRowView(host: host, actionState: viewModel.actionState(for: host.id))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                        if viewModel.actionState(for: host.id) == nil {
                            if host.enabled?.boolValue ?? true {
                                Button("Disable", systemImage: "stop.circle") {
                                    Task { await viewModel.setEnabled(host.id, enabled: false) }
                                }
                                .tint(.orange)
                            } else {
                                Button("Enable", systemImage: "play.circle") {
                                    Task { await viewModel.setEnabled(host.id, enabled: true) }
                                }
                                .tint(.green)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(host.id) }
                            }
                        }
                    }
                    .contextMenu {
                        if viewModel.actionState(for: host.id) == nil {
                            if host.enabled?.boolValue ?? true {
                                Button("Disable", systemImage: "stop.circle") {
                                    Task { await viewModel.setEnabled(host.id, enabled: false) }
                                }
                            } else {
                                Button("Enable", systemImage: "play.circle") {
                                    Task { await viewModel.setEnabled(host.id, enabled: true) }
                                }
                            }
                            Button("Edit", systemImage: "pencil") {
                                editingHost = host
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(host.id) }
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
        .background(ProxyDestinationGradientBackground(accent: .redirection))
    }
}
