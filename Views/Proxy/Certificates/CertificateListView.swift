import SwiftUI

struct CertificateListView: View {
    @State private var viewModel: NPMCertificatesViewModel
    @State private var showEditor = false

    init(client: NPMClient) {
        _viewModel = State(initialValue: NPMCertificatesViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.items.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading certificates…")
            } else if let error = viewModel.loadError, viewModel.items.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.items.isEmpty {
                ContentUnavailableView {
                    Label("No certificates", systemImage: "checkmark.seal")
                } description: {
                    Text("Request a Let's Encrypt certificate to get started.")
                } actions: {
                    Button("Add certificate", systemImage: "plus") {
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
        .navigationTitle("Certificates")
        .searchable(text: $viewModel.searchText, prompt: "Search certificates")
        .refreshable { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add", systemImage: "plus") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                CertificateEditorView(viewModel: viewModel)
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var contentList: some View {
        List {
            ForEach(viewModel.visibleItems) { cert in
                CertificateRowView(cert: cert, actionState: viewModel.actionState(for: cert.id))
                    .swipeActions(edge: .trailing) {
                        if viewModel.actionState(for: cert.id) == nil {
                            Button("Renew", systemImage: "arrow.clockwise") {
                                Task { await viewModel.renew(cert.id) }
                            }
                            .tint(.blue)
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(cert.id) }
                            }
                        }
                    }
                    .contextMenu {
                        if viewModel.actionState(for: cert.id) == nil {
                            Button("Renew", systemImage: "arrow.clockwise") {
                                Task { await viewModel.renew(cert.id) }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await viewModel.delete(cert.id) }
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
        .background(ProxyDestinationGradientBackground(accent: .certificate))
    }
}
