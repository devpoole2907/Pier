import SwiftUI
import SwiftData

/// Lists Docker images. Supports search, pull-to-refresh, and the pull/push add flow.
struct ImagesListView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ImagesViewModel
    @State private var editMode: EditMode = .inactive
    @State private var isShowingPullSheet = false
    @State private var selectedImageIDs: Set<String> = []
    @State private var pendingDelete: DockerImage?
    @State private var isShowingBulkDeleteAlert = false

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: ImagesViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.images.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading images…")
            } else if let error = viewModel.loadError, viewModel.images.isEmpty {
                ErrorView(error: error, retry: {
                    Task { await viewModel.load() }
                })
            } else if viewModel.images.isEmpty {
                EmptyStateView(
                    title: "No images",
                    systemImage: "photo.stack",
                    message: "Pull an image to get started."
                )
            } else if viewModel.visibleImages.isEmpty {
                ContentUnavailableView.search
            } else {
                List(selection: $selectedImageIDs) {
                    ForEach(viewModel.visibleImages) { image in
                        row(for: image)
                    }
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
            Text("This deletes \(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s"). Remove forcefully if other images depend on them.")
        }
        .sheet(isPresented: $isShowingPullSheet) {
            NavigationStack {
                ImagePullView(viewModel: viewModel)
            }
        }
        .alert(item: $pendingDelete) { image in
            Alert(
                title: Text("Delete image?"),
                message: Text("This deletes \(image.displayName). Remove forcefully if other images depend on it."),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await viewModel.delete(image, force: true) }
                },
                secondaryButton: .cancel()
            )
        }
        .task { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var imagesToolbar: some ToolbarContent {
        if !viewModel.visibleImages.isEmpty {
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
                Button("Delete selected", systemImage: "trash") {
                    isShowingBulkDeleteAlert = true
                }
                .disabled(selectedImageIDs.isEmpty)
            } else {
                Button("Pull image", systemImage: "arrow.down.circle") {
                    isShowingPullSheet = true
                }
            }
        }
    }

    private var selectedImages: [DockerImage] {
        viewModel.visibleImages.filter { selectedImageIDs.contains($0.id) }
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

    @ViewBuilder
    private func row(for image: DockerImage) -> some View {
        if isSelecting {
            ImageRowView(image: image)
            .tag(image.id)
        } else {
            ImageRowView(image: image)
                .tag(image.id)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingDelete = image
                    }
                }
        }
    }

    private func deleteSelectedImages() async {
        let images = selectedImages
        guard !images.isEmpty else { return }
        let deletedIDs = await viewModel.delete(images, force: true)
        selectedImageIDs.subtract(deletedIDs)
    }

}
