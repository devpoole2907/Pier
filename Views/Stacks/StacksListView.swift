import SwiftUI
import SwiftData

/// Top-level list of Portainer-managed compose stacks.
struct StacksListView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: StacksViewModel
    @State private var editMode: EditMode = .inactive
    @State private var selectedStackIDs: Set<Int> = []
    @State private var pendingBulkAction: BulkStackAction?

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: StacksViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.stacks.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading stacks…")
            } else if let error = viewModel.loadError, viewModel.stacks.isEmpty {
                ErrorView(error: error, retry: {
                    Task { await viewModel.load() }
                })
            } else if viewModel.stacks.isEmpty {
                EmptyStateView(
                    title: "No stacks",
                    systemImage: "square.stack.3d.up",
                    message: "Compose stacks managed by Portainer will appear here."
                )
            } else {
                List(selection: $selectedStackIDs) {
                    ForEach(viewModel.stacks) { stack in
                        row(for: stack)
                    }
                }
            }
        }
        .toolbar { stacksToolbar }
        .navigationSubtitle(navigationSubtitleText)
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { _, mode in
            if mode == .inactive {
                selectedStackIDs.removeAll()
            }
        }
        .alert(item: $pendingBulkAction, content: bulkStackAlert)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    @ToolbarContentBuilder
    private var stacksToolbar: some ToolbarContent {
        ToolbarItem(placement: toolbarLeadingPlacement) {
            if !viewModel.stacks.isEmpty {
                EditButton()
            }
        }
        ToolbarItem(placement: toolbarTrailingPlacement) {
            if isSelecting {
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Start selected", systemImage: "play.fill") {
                        pendingBulkAction = .start
                    }
                    .disabled(inactiveSelectedStacks.isEmpty)
                    Button("Stop selected", systemImage: "stop.fill") {
                        pendingBulkAction = .stop
                    }
                    .disabled(activeSelectedStacks.isEmpty)
                    Button("Delete selected", systemImage: "trash", role: .destructive) {
                        pendingBulkAction = .delete
                    }
                    .disabled(selectedStacks.isEmpty)
                }
                .disabled(selectedStackIDs.isEmpty)
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

    private var toolbarLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    private var isSelecting: Bool {
        editMode.isEditing
    }

    private var selectedStacks: [Stack] {
        viewModel.stacks.filter { selectedStackIDs.contains($0.id) }
    }

    private var activeSelectedStacks: [Stack] {
        selectedStacks.filter(\.isActive)
    }

    private var inactiveSelectedStacks: [Stack] {
        selectedStacks.filter { !$0.isActive }
    }

    private var selectionSubtitle: String? {
        selectedStackIDs.isEmpty ? nil : "\(selectedStackIDs.count) selected"
    }

    private var activeHostName: String? {
        hostManager.activeClient(in: modelContext)?.host.name
    }

    private var navigationSubtitleText: String {
        selectionSubtitle ?? activeHostName ?? ""
    }

    @ViewBuilder
    private func row(for stack: Stack) -> some View {
        if isSelecting {
            StackRowView(stack: stack)
                .tag(stack.id)
        } else {
            NavigationLink(value: stack) {
                StackRowView(stack: stack)
            }
            .tag(stack.id)
        }
    }

    private func bulkStackAlert(for action: BulkStackAction) -> Alert {
        let count = action.targetStacks(in: selectedStacks).count
        return Alert(
            title: Text(action.title),
            message: Text(action.message(count: count)),
            primaryButton: .destructive(Text(action.confirmLabel)) {
                Task { await confirmBulkAction(action) }
            },
            secondaryButton: .cancel {
                pendingBulkAction = nil
            }
        )
    }

    private func confirmBulkAction(_ action: BulkStackAction) async {
        pendingBulkAction = nil
        let targets = action.targetStacks(in: selectedStacks)
        guard !targets.isEmpty else { return }
        switch action {
        case .start:
            await viewModel.start(targets)
        case .stop:
            await viewModel.stop(targets)
        case .delete:
            await viewModel.delete(targets)
        }
        selectedStackIDs.subtract(targets.map(\.id))
    }
}

private enum BulkStackAction: String, Identifiable {
    case start
    case stop
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: "Start selected stacks?"
        case .stop: "Stop selected stacks?"
        case .delete: "Delete selected stacks?"
        }
    }

    var confirmLabel: String {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .delete: "Delete"
        }
    }

    func message(count: Int) -> String {
        switch self {
        case .start:
            "This starts \(count) inactive stack\(count == 1 ? "" : "s")."
        case .stop:
            "This stops \(count) active stack\(count == 1 ? "" : "s")."
        case .delete:
            "This deletes \(count) stack\(count == 1 ? "" : "s"). This cannot be undone."
        }
    }

    func targetStacks(in stacks: [Stack]) -> [Stack] {
        switch self {
        case .start:
            stacks.filter { !$0.isActive }
        case .stop:
            stacks.filter(\.isActive)
        case .delete:
            stacks
        }
    }
}
