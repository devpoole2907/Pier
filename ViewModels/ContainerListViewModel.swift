import Foundation
import Observation

/// Filter chip choice for the container list.
enum ContainerFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case running
    case stopped
    case byStack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .running: "Running"
        case .stopped: "Stopped"
        case .byStack: "By stack"
        }
    }
}

@MainActor
@Observable
final class ContainerListViewModel {
    private(set) var containers: [Container] = []
    private(set) var isLoading = false
    private(set) var loadError: PortainerError?
    private(set) var actionStatesByContainerID: [String: ContainerActionState] = [:]

    var filter: ContainerFilter = .all
    var searchText: String = ""
    var pendingDestructiveAction: PendingContainerAction?

    private let client: PortainerClient
    private let endpointID: Int
    private var includesStopped = true

    init(client: PortainerClient, endpointID: Int) {
        self.client = client
        self.endpointID = endpointID
    }

    /// Filtered + grouped (running before stopped) view of `containers` honouring the active filter and search.
    var visibleContainers: [Container] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base: [Container]
        switch filter {
        case .all, .byStack:
            base = containers
        case .running:
            base = containers.filter { $0.state == .running }
        case .stopped:
            base = containers.filter { $0.state != .running }
        }
        let searched = trimmed.isEmpty
            ? base
            : base.filter {
                $0.displayName.localizedStandardContains(trimmed)
                    || $0.image.localizedStandardContains(trimmed)
            }
        return searched.sorted { lhs, rhs in
            if lhs.state.sortRank != rhs.state.sortRank {
                return lhs.state.sortRank < rhs.state.sortRank
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// Containers grouped by stack name (for the "By stack" filter view).
    var containersByStack: [(String, [Container])] {
        let grouped = Dictionary(grouping: visibleContainers) { $0.stackName ?? "Standalone" }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    func load(includeStopped: Bool = true) async {
        includesStopped = includeStopped
        isLoading = true
        defer { isLoading = false }
        do {
            self.containers = try await client.listContainers(endpointID: endpointID, includeStopped: includeStopped)
            self.loadError = nil
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    func refresh(includeStopped: Bool = true) async {
        await load(includeStopped: includeStopped)
    }

    /// Long-running polling loop. Returns when the surrounding task is cancelled.
    /// Drive this from a view's `.task(id:)` so cancellation flows naturally on view disappearance
    /// or interval change.
    func runPolling(every seconds: TimeInterval, includeStopped: Bool = true) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await load(includeStopped: includesStopped)
        }
    }

    // MARK: - Container actions

    func start(_ container: Container) async {
        await performAction(for: container, actionState: .starting) {
            try await self.client.startContainer(endpointID: self.endpointID, containerID: container.id)
        }
    }

    func stop(_ container: Container) {
        pendingDestructiveAction = PendingContainerAction(container: container, action: .stop)
    }

    func restart(_ container: Container) {
        pendingDestructiveAction = PendingContainerAction(container: container, action: .restart)
    }

    func kill(_ container: Container) {
        pendingDestructiveAction = PendingContainerAction(container: container, action: .kill)
    }

    func delete(_ container: Container) {
        pendingDestructiveAction = PendingContainerAction(container: container, action: .delete)
    }

    func confirmDestructiveAction() async {
        guard let pending = pendingDestructiveAction else { return }
        pendingDestructiveAction = nil
        switch pending.action {
        case .stop:
            await performAction(for: pending.container, actionState: .stopping) {
                try await self.client.stopContainer(endpointID: self.endpointID, containerID: pending.container.id)
            }
        case .restart:
            await performAction(for: pending.container, actionState: .restarting) {
                try await self.client.restartContainer(endpointID: self.endpointID, containerID: pending.container.id)
            }
        case .kill:
            await performAction(for: pending.container, actionState: .killing) {
                try await self.client.killContainer(endpointID: self.endpointID, containerID: pending.container.id)
            }
        case .delete:
            await performAction(for: pending.container, actionState: .deleting) {
                try await self.client.deleteContainer(endpointID: self.endpointID, containerID: pending.container.id, force: true, removeVolumes: false)
            }
        }
    }

    func start(_ containers: [Container]) async {
        await performActions(containers, actionState: .starting) { container in
            try await self.client.startContainer(endpointID: self.endpointID, containerID: container.id)
        }
    }

    func performBulkAction(_ action: DestructiveAction, on containers: [Container]) async {
        await performActions(containers, actionState: ContainerActionState(action: action)) { container in
            switch action {
            case .stop:
                try await self.client.stopContainer(endpointID: self.endpointID, containerID: container.id)
            case .restart:
                try await self.client.restartContainer(endpointID: self.endpointID, containerID: container.id)
            case .kill:
                try await self.client.killContainer(endpointID: self.endpointID, containerID: container.id)
            case .delete:
                try await self.client.deleteContainer(endpointID: self.endpointID, containerID: container.id, force: true, removeVolumes: false)
            }
        }
    }

    func actionState(for container: Container) -> ContainerActionState? {
        actionStatesByContainerID[container.id]
    }

    func isActionInProgress(for container: Container) -> Bool {
        actionState(for: container) != nil
    }

    private func performAction(
        for container: Container,
        actionState: ContainerActionState,
        body: @escaping @Sendable () async throws -> Void
    ) async {
        actionStatesByContainerID[container.id] = actionState
        defer { actionStatesByContainerID[container.id] = nil }
        do {
            try await body()
            await load(includeStopped: includesStopped)
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    private func performActions(
        _ containers: [Container],
        actionState: ContainerActionState,
        operation: @escaping @Sendable (Container) async throws -> Void
    ) async {
        for container in containers {
            actionStatesByContainerID[container.id] = actionState
        }
        defer {
            for container in containers {
                actionStatesByContainerID[container.id] = nil
            }
        }
        do {
            for container in containers {
                try await operation(container)
            }
            await load(includeStopped: includesStopped)
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }
}

struct PendingContainerAction: Identifiable {
    let container: Container
    let action: DestructiveAction

    var id: String { "\(container.id)-\(action.rawValue)" }
}

enum ContainerActionState: String, Sendable {
    case starting
    case stopping
    case restarting
    case killing
    case deleting

    init(action: DestructiveAction) {
        switch action {
        case .stop:
            self = .stopping
        case .restart:
            self = .restarting
        case .kill:
            self = .killing
        case .delete:
            self = .deleting
        }
    }

    var displayName: String {
        switch self {
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .restarting: "Restarting"
        case .killing: "Killing"
        case .deleting: "Deleting"
        }
    }

    var rowDetailText: String {
        "\(displayName) request in progress"
    }
}
