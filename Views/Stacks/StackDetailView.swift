import SwiftUI

/// Stack detail. Shows summary, services in the stack, and a YAML editor for the compose file.
struct StackDetailView: View {
    let stack: Stack
    @State private var viewModel: StacksViewModel
    @State private var isShowingEditor = false
    @State private var pendingDelete = false
    @State private var pendingStop = false

    private let containersClient: PortainerClient
    private let containersEndpointID: Int
    @State private var containerListVM: ContainerListViewModel

    init(stack: Stack, client: PortainerClient, endpointID: Int) {
        self.stack = stack
        self.containersClient = client
        self.containersEndpointID = endpointID
        _viewModel = State(initialValue: StacksViewModel(client: client, endpointID: endpointID))
        _containerListVM = State(initialValue: ContainerListViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        List {
            Section("Stack") {
                LabeledContent("Status") {
                    Text(stack.isActive ? "Active" : "Inactive")
                        .foregroundStyle(stack.isActive ? .green : .secondary)
                }
                if let created = stack.creationDate {
                    LabeledContent("Created") {
                        Text(created, format: .dateTime.day().month().year())
                    }
                }
                if let updated = stack.updateDate {
                    LabeledContent("Updated") {
                        Text(updated, format: .dateTime.day().month().year())
                    }
                }
            }

            StackServicesSection(stackName: stack.name, viewModel: containerListVM)

            Section("Compose file") {
                Button("View / edit YAML", systemImage: "doc.text") {
                    Task {
                        await viewModel.loadFile(for: stack)
                        isShowingEditor = true
                    }
                }
            }
        }
        .navigationTitle(stack.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .task {
            await containerListVM.load()
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                StackEditorView(initialContent: viewModel.fileContent, stackName: stack.name)
            }
        }
        .alert("Delete stack?", isPresented: $pendingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(stack) }
            }
        } message: {
            Text("This removes the stack and its containers. This action cannot be undone.")
        }
        .alert("Stop stack?", isPresented: $pendingStop) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task { await viewModel.stop(stack) }
            }
        } message: {
            Text("This stops \(stack.name) and all its services.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: toolbarTrailingPlacement) {
            Menu("Actions", systemImage: "ellipsis.circle") {
                if stack.isActive {
                    Button("Stop stack", systemImage: "stop.fill") {
                        pendingStop = true
                    }
                } else {
                    Button("Start stack", systemImage: "play.fill") {
                        Task { await viewModel.start(stack) }
                    }
                }
                Button("Delete stack", systemImage: "trash", role: .destructive) {
                    pendingDelete = true
                }
            }
        }
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}
