import SwiftUI

struct AccessListListView: View {
    @State private var viewModel: NPMAccessListsViewModel
    @State private var showEditor = false
    @State private var editingList: NPMAccessList?

    init(client: NPMClient) {
        _viewModel = State(initialValue: NPMAccessListsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading access lists…")
            } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("No access lists", systemImage: "lock.shield")
                } description: {
                    Text("Create an access list for auth or IP restrictions.")
                } actions: {
                    Button("Add access list", systemImage: "plus") {
                        editingList = nil
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
        .navigationTitle("Access Lists")
        .searchable(text: $viewModel.searchText, prompt: "Search lists")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add", systemImage: "plus") {
                    editingList = nil
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AccessListEditorView(viewModel: viewModel, existing: editingList)
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(viewModel.visibleItems) { list in
                Button {
                    editingList = list
                    showEditor = true
                } label: {
                    AccessListRowView(list: list, actionState: viewModel.actionState(for: list.id))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                        if viewModel.actionState(for: list.id) == nil {
                            Button("Edit", systemImage: "pencil") {
                                editingList = list
                                showEditor = true
                            }
                            .tint(.blue)
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(list.id) }
                            }
                        }
                    }
                    .contextMenu {
                        if viewModel.actionState(for: list.id) == nil {
                            Button("Edit", systemImage: "pencil") {
                                editingList = list
                                showEditor = true
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(list.id) }
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
        .background(ProxyDestinationGradientBackground(accent: .accessList))
    }
}
