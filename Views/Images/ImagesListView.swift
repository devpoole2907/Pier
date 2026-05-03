import SwiftUI

/// Lists Docker images. Supports search, pull-to-refresh, and the pull/push add flow.
struct ImagesListView: View {
    @State private var viewModel: ImagesViewModel
    @State private var isShowingPullSheet = false
    @State private var pendingDelete: DockerImage?

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: ImagesViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.images.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading images…")
            } else if let error = viewModel.loadError, viewModel.images.isEmpty {
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.images.isEmpty {
                EmptyStateView(
                    title: "No images",
                    systemImage: "photo.stack",
                    message: "Pull an image to get started."
                )
            } else if viewModel.visibleImages.isEmpty {
                ContentUnavailableView.search
            } else {
                List {
                    ForEach(viewModel.visibleImages) { image in
                        ImageRowView(image: image)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    pendingDelete = image
                                }
                            }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search images")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: toolbarTrailingPlacement) {
                Button("Pull image", systemImage: "arrow.down.circle") {
                    isShowingPullSheet = true
                }
            }
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

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
