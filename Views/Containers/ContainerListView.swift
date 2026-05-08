import SwiftUI
import SwiftData

/// Main container list view. Orchestrates the view model, filter chips, search, and tap actions.
struct ContainerListView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ContainerListViewModel
    @State private var editMode: EditMode = .inactive
    @State private var selectedContainerIDs: Set<String> = []
    @State private var pendingBulkAction: BulkContainerAction?
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalRaw: Int = RefreshInterval.medium.rawValue
    @AppStorage("showStoppedContainers") private var showStoppedContainers: Bool = true

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: ContainerListViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        Group {
            if viewModel.containers.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading containers…")
            } else if let error = viewModel.loadError, viewModel.containers.isEmpty {
                ErrorView(error: error, retry: {
                    Task { await viewModel.load(includeStopped: showStoppedContainers) }
                })
            } else if viewModel.containers.isEmpty {
                EmptyStateView(
                    title: "No containers",
                    systemImage: "shippingbox",
                    message: "This host has no Docker containers yet."
                )
            } else if viewModel.visibleContainers.isEmpty {
                ContentUnavailableView.search
            } else {
                contentList
            }
        }
        .environment(\.editMode, $editMode)
        .searchable(text: $viewModel.searchText, prompt: "Search containers")
        .refreshable { await viewModel.refresh(includeStopped: showStoppedContainers) }
        .toolbar { selectionToolbar }
        .alert(item: $viewModel.pendingDestructiveAction, content: destructiveContainerAlert)
        .alert(item: $pendingBulkAction, content: bulkContainerAlert)
        .task(id: showStoppedContainers) {
            await viewModel.load(includeStopped: showStoppedContainers)
        }
        .task(id: pollingConfiguration) {
            guard let interval = RefreshInterval(rawValue: refreshIntervalRaw)?.seconds else { return }
            await viewModel.runPolling(every: interval, includeStopped: showStoppedContainers)
        }
        .navigationSubtitle(navigationSubtitleText)
    }

    @ViewBuilder
    private var contentList: some View {
        if viewModel.filter == .byStack {
            ContainerListByStackView(
                viewModel: viewModel,
                selection: $selectedContainerIDs,
                isSelecting: isSelecting
            )
        } else {
            ContainerListFlatView(
                viewModel: viewModel,
                selection: $selectedContainerIDs,
                isSelecting: isSelecting
            )
        }
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        if !viewModel.visibleContainers.isEmpty {
            ToolbarItem(placement: .platformTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        editMode = isSelecting ? .inactive : .active
                    }
                    if !editMode.isEditing {
                        selectedContainerIDs.removeAll()
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
                Menu("Actions", systemImage: "ellipsis.circle") {
                    Button("Start selected", systemImage: "play.fill") {
                        pendingBulkAction = .start
                    }
                    .disabled(startableContainers.isEmpty)
                    Button("Stop selected", systemImage: "stop.fill") {
                        pendingBulkAction = .stop
                    }
                    .disabled(runningSelectedContainers.isEmpty)
                    Button("Restart selected", systemImage: "arrow.clockwise") {
                        pendingBulkAction = .restart
                    }
                    .disabled(runningSelectedContainers.isEmpty)
                    Button("Kill selected", systemImage: "bolt.slash.fill", role: .destructive) {
                        pendingBulkAction = .kill
                    }
                    .disabled(runningSelectedContainers.isEmpty)
                    Button("Delete selected", systemImage: "trash", role: .destructive) {
                        pendingBulkAction = .delete
                    }
                    .disabled(selectedContainers.isEmpty)
                }
                .disabled(selectedContainerIDs.isEmpty)
            } else {
                Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                    Picker("Filter", selection: $viewModel.filter) {
                        ForEach(ContainerFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                }
            }
        }
    }

    private var selectionSubtitle: String? {
        selectedContainerIDs.isEmpty ? nil : "\(selectedContainerIDs.count) selected"
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

    private var selectedContainers: [Container] {
        viewModel.visibleContainers.filter { selectedContainerIDs.contains($0.id) }
    }

    private var pollingConfiguration: ContainerPollingConfiguration {
        ContainerPollingConfiguration(
            refreshIntervalRaw: refreshIntervalRaw,
            showStoppedContainers: showStoppedContainers
        )
    }

    private var runningSelectedContainers: [Container] {
        selectedContainers.filter { $0.state == .running }
    }

    private var startableContainers: [Container] {
        selectedContainers.filter { $0.state != .running }
    }

    private func destructiveContainerAlert(for pending: PendingContainerAction) -> Alert {
        let container = pending.container
        switch pending.action {
        case .stop:
            return Alert(
                title: Text("Stop container?"),
                message: Text("This stops \(container.displayName) gracefully."),
                primaryButton: .destructive(Text("Stop")) { Task { await viewModel.confirmDestructiveAction() } },
                secondaryButton: .cancel()
            )
        case .restart:
            return Alert(
                title: Text("Restart container?"),
                message: Text("This restarts \(container.displayName)."),
                primaryButton: .destructive(Text("Restart")) { Task { await viewModel.confirmDestructiveAction() } },
                secondaryButton: .cancel()
            )
        case .kill:
            return Alert(
                title: Text("Kill container?"),
                message: Text("This sends SIGKILL to \(container.displayName) immediately."),
                primaryButton: .destructive(Text("Kill")) { Task { await viewModel.confirmDestructiveAction() } },
                secondaryButton: .cancel()
            )
        case .delete:
            return Alert(
                title: Text("Delete container?"),
                message: Text("This removes \(container.displayName). It cannot be undone."),
                primaryButton: .destructive(Text("Delete")) { Task { await viewModel.confirmDestructiveAction() } },
                secondaryButton: .cancel()
            )
        }
    }

    private func bulkContainerAlert(for action: BulkContainerAction) -> Alert {
        let count = action.targetContainers(in: selectedContainers).count
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

    private func confirmBulkAction(_ action: BulkContainerAction) async {
        pendingBulkAction = nil
        let targets = action.targetContainers(in: selectedContainers)
        guard !targets.isEmpty else { return }
        switch action {
        case .start:
            await viewModel.start(targets)
        case .stop:
            await viewModel.performBulkAction(.stop, on: targets)
        case .restart:
            await viewModel.performBulkAction(.restart, on: targets)
        case .kill:
            await viewModel.performBulkAction(.kill, on: targets)
        case .delete:
            await viewModel.performBulkAction(.delete, on: targets)
        }
        if viewModel.loadError == nil {
            selectedContainerIDs.subtract(targets.map(\.id))
        }
    }
}

private struct ContainerPollingConfiguration: Equatable {
    let refreshIntervalRaw: Int
    let showStoppedContainers: Bool
}

private enum BulkContainerAction: String, Identifiable {
    case start
    case stop
    case restart
    case kill
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: "Start selected containers?"
        case .stop: "Stop selected containers?"
        case .restart: "Restart selected containers?"
        case .kill: "Kill selected containers?"
        case .delete: "Delete selected containers?"
        }
    }

    var confirmLabel: String {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .restart: "Restart"
        case .kill: "Kill"
        case .delete: "Delete"
        }
    }

    func message(count: Int) -> String {
        switch self {
        case .start:
            "This starts \(count) stopped container\(count == 1 ? "" : "s")."
        case .stop:
            "This stops \(count) running container\(count == 1 ? "" : "s") gracefully."
        case .restart:
            "This restarts \(count) running container\(count == 1 ? "" : "s")."
        case .kill:
            "This sends SIGKILL to \(count) running container\(count == 1 ? "" : "s") immediately."
        case .delete:
            "This removes \(count) container\(count == 1 ? "" : "s"). It cannot be undone."
        }
    }

    func targetContainers(in containers: [Container]) -> [Container] {
        switch self {
        case .start:
            containers.filter { $0.state != .running }
        case .stop, .restart, .kill:
            containers.filter { $0.state == .running }
        case .delete:
            containers
        }
    }
}
