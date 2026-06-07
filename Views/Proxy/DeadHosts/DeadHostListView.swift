import SwiftUI

struct DeadHostListView: View {
    @State private var viewModel: NPMDeadHostsViewModel
    @State private var showEditor = false
    @State private var editingHost: NPMDeadHost?

    init(client: NPMClient) {
        _viewModel = State(initialValue: NPMDeadHostsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading 404 hosts…")
            } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("No 404 hosts", systemImage: "xmark.octagon")
                } description: {
                    Text("Create a custom 404 response.")
                } actions: {
                    Button("Add 404 host", systemImage: "plus") {
                        editingHost = nil
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
        .navigationTitle("404 Hosts")
        .searchable(text: $viewModel.searchText, prompt: "Search domains")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add", systemImage: "plus") {
                    editingHost = nil
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                DeadHostEditorView(viewModel: viewModel, existing: editingHost)
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
                    showEditor = true
                } label: {
                    DeadHostRowView(host: host, actionState: viewModel.actionState(for: host.id))
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
                                showEditor = true
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
        .background(ProxyDestinationGradientBackground(accent: .dead))
    }
}
