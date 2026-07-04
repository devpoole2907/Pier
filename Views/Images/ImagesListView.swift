import SwiftUI
import SwiftData

/// Lists Docker images for the active Komodo server (or every reachable server, merged, in "All
/// servers" mode). Supports search, pull-to-refresh, per-row and bulk delete, and pruning unused
/// images. There is no image pull in Komodo, so unlike the old Portainer-backed view this has no
/// add flow.
struct ImagesListView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImagesViewModel
    @State private var editMode: EditMode = .inactive
    @State private var selectedImageIDs: Set<String> = []
    @State private var pendingDelete: ImageListItem?
    @State private var isShowingBulkDeleteAlert = false
    @State private var isShowingPruneAlert = false

    init(client: KomodoClient, serverID: String?, servers: [KomodoServer]) {
        _viewModel = State(initialValue: ImagesViewModel(client: client, serverID: serverID, servers: servers))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !hostManager.servers.isEmpty {
                TrawlSegmentBar(
                    "Server scope",
                    selection: serverScopeBinding,
                    items: serverScopeItems
                )
            }

            Group {
                if viewModel.items.isEmpty, viewModel.isLoading {
                    LoadingView(message: "Loading images…")
                } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                    ErrorView(error: error, retry: {
                        Task { await viewModel.load() }
                    })
                } else if viewModel.items.isEmpty {
                    EmptyStateView(
                        title: "No images",
                        systemImage: "photo.stack",
                        message: "No Docker images were found."
                    )
                } else if viewModel.visibleItems.isEmpty {
                    ContentUnavailableView.search
                } else {
                    // Only bind the selection set while actively selecting. Otherwise a plain tap on a
                    // NavigationLink row can populate the set, leaving a phantom "1 selected" subtitle after
                    // navigating back even though edit mode was never entered.
                    List(selection: isSelecting ? $selectedImageIDs : .constant([])) {
                        ForEach(viewModel.visibleItems) { item in
                            row(for: item)
                        }
                    }
                    .softScrollEdges()
                }
            }
        }
        .environment(\.editMode, $editMode)
        .searchable(text: $viewModel.searchText, prompt: "Search images")
        .refreshable { await viewModel.load() }
        .toolbar { imagesToolbar }
        .navigationSubtitle(navigationSubtitleText)
        .alert("Delete selected images?", isPresented: $isShowingBulkDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await deleteSelectedImages() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes \(selectedItems.count) image\(selectedItems.count == 1 ? "" : "s").")
        }
        .alert(item: $pendingDelete) { item in
            Alert(
                title: Text("Delete image?"),
                message: Text("This deletes \(item.image.displayName)."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await viewModel.delete(item) }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Prune unused images?", isPresented: $isShowingPruneAlert) {
            Button("Prune", role: .destructive) {
                Task { await viewModel.prune() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(pruneMessage)
        }
        .task { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var imagesToolbar: some ToolbarContent {
        if !viewModel.visibleItems.isEmpty {
            ToolbarItem(placement: .platformTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        editMode = isSelecting ? .inactive : .active
                    }
                    if !editMode.isEditing {
                        selectedImageIDs.removeAll()
                    }
                } label: {
                    if isSelecting {
                        Image(systemName: "xmark")
                            .accessibilityLabel("Done")
                    } else {
                        Text("Select")
                    }
                }
            }

            ToolbarSpacer(.fixed, placement: .platformTrailing)
        }

        ToolbarItem(placement: .platformTrailing) {
            if isSelecting {
                Button("Delete selected", systemImage: "trash", role: .destructive) {
                    isShowingBulkDeleteAlert = true
                }
                .disabled(selectedImageIDs.isEmpty)
            } else {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Prune unused images", systemImage: "sparkles") {
                        isShowingPruneAlert = true
                    }
                    .disabled(viewModel.isPruning)
                }
            }
        }
    }

    private var serverScopeBinding: Binding<String?> {
        Binding(
            get: { hostManager.activeServerID },
            set: { hostManager.setActiveServer($0) }
        )
    }

    private var serverScopeItems: [TrawlSegmentBarItem<String?>] {
        [TrawlSegmentBarItem("All", value: nil)]
            + hostManager.servers.map { server in
                TrawlSegmentBarItem(server.name, value: server.id)
            }
    }

    private var selectedItems: [ImageListItem] {
        viewModel.visibleItems.filter { selectedImageIDs.contains($0.id) }
    }

    private var selectionSubtitle: String? {
        selectedImageIDs.isEmpty ? nil : "\(selectedImageIDs.count) selected"
    }

    private var isSelecting: Bool {
        editMode.isEditing
    }

    private var activeHostName: String? {
        hostManager.activeClient(in: modelContext)?.host.name
    }

    private var navigationSubtitleText: String {
        selectionSubtitle ?? activeHostName ?? ""
    }

    private var pruneMessage: String {
        hostManager.activeServerID == nil
            ? "This removes unused images from every reachable server."
            : "This removes unused images from this server."
    }

    private func serverName(for serverID: String) -> String {
        hostManager.servers.first(where: { $0.id == serverID })?.name ?? serverID
    }

    @ViewBuilder
    private func row(for item: ImageListItem) -> some View {
        let subtitleServerName = hostManager.activeServerID == nil ? serverName(for: item.serverID) : nil
        if isSelecting {
            ImageRowView(image: item.image, serverName: subtitleServerName)
                .tag(item.id)
        } else {
            ImageRowView(image: item.image, serverName: subtitleServerName)
                .tag(item.id)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingDelete = item
                    }
                }
        }
    }

    private func deleteSelectedImages() async {
        let items = selectedItems
        guard !items.isEmpty else { return }
        let deletedIDs = await viewModel.delete(items)
        selectedImageIDs.subtract(deletedIDs)
    }
}
