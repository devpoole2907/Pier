import Foundation
import Observation

/// Filter chip choice for the container list.
enum ContainerFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case running
    case stopped
    case byServer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .running: "Running"
        case .stopped: "Stopped"
        case .byServer: "By server"
        }
    }
}

@MainActor
@Observable
final class ContainerListViewModel {
    private(set) var containers: [Container] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?
    private(set) var actionStatesByContainerID: [String: ContainerActionState] = [:]

    var filter: ContainerFilter = .all
    var searchText: String = ""
    var pendingDestructiveAction: PendingContainerAction?

    private let client: KomodoClient
    /// Scopes the list to a single Komodo server, or `nil` for "All servers".
    private let serverID: String?
    private var includesStopped = true

    init(client: KomodoClient, serverID: String?) {
        self.client = client
        self.serverID = serverID
    }

    /// `containers` filtered by the "show stopped containers" app setting. Komodo's list endpoints
    /// have no server-side "include stopped" flag (unlike the previous backend's call), so this is now
    /// applied client-side rather than by varying the network request.
    private var scopedContainers: [Container] {
        includesStopped ? containers : containers.filter { $0.state == .running }
    }

    /// Filtered + grouped (running before stopped) view of `containers` honouring the active filter and search.
    var visibleContainers: [Container] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base: [Container]
        switch filter {
        case .all, .byServer:
            base = scopedContainers
        case .running:
            base = scopedContainers.filter { $0.state == .running }
        case .stopped:
            base = scopedContainers.filter { $0.state != .running }
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

    /// Containers grouped by server ID (for the "By server" filter view). Komodo containers don't
    /// carry a compose-project name on the list item, so grouping is by server rather than by
    /// compose stack; the view resolves each server's display name via `HostManager.servers`.
    var containersByServer: [(String, [Container])] {
        let grouped = Dictionary(grouping: visibleContainers) { $0.serverID }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    func load(includeStopped: Bool = true) async {
        includesStopped = includeStopped
        isLoading = true
        defer { isLoading = false }
        do {
            self.containers = try await client.listContainers(serverID: serverID)
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    func refresh(includeStopped: Bool = true) async {
        await load(includeStopped: includeStopped)
    }

    /// Long-running polling loop. Returns when the surrounding task is cancelled.
    /// Drive this from a view's `.task(id:)` so cancellation flows naturally on view disappearance
    /// or interval change. Since stats are inline on `Container`, this refresh also keeps the
    /// per-container CPU%/mem shown in list rows current.
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
            try await self.client.startContainer(serverID: container.serverID, containerID: container.id)
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
        let container = pending.container
        switch pending.action {
        case .stop:
            await performAction(for: container, actionState: .stopping) {
                try await self.client.stopContainer(serverID: container.serverID, containerID: container.id)
            }
        case .restart:
            await performAction(for: container, actionState: .restarting) {
                try await self.client.restartContainer(serverID: container.serverID, containerID: container.id)
            }
        case .kill:
            await performAction(for: container, actionState: .killing) {
                // Komodo has no dedicated "kill" call; a SIGKILL stop with no grace period is the
                // equivalent of the old "kill" action.
                try await self.client.stopContainer(serverID: container.serverID, containerID: container.id, signal: "SIGKILL", time: 0)
            }
        case .delete:
            await performAction(for: container, actionState: .deleting) {
                try await self.client.destroyContainer(serverID: container.serverID, containerID: container.id)
            }
        }
    }

    func start(_ containers: [Container]) async {
        await performActions(containers, actionState: .starting) { container in
            try await self.client.startContainer(serverID: container.serverID, containerID: container.id)
        }
    }

    func performBulkAction(_ action: DestructiveAction, on containers: [Container]) async {
        await performActions(containers, actionState: ContainerActionState(action: action)) { container in
            switch action {
            case .stop:
                try await self.client.stopContainer(serverID: container.serverID, containerID: container.id)
            case .restart:
                try await self.client.restartContainer(serverID: container.serverID, containerID: container.id)
            case .kill:
                try await self.client.stopContainer(serverID: container.serverID, containerID: container.id, signal: "SIGKILL", time: 0)
            case .delete:
                try await self.client.destroyContainer(serverID: container.serverID, containerID: container.id)
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
            InAppNotificationCenter.shared.showSuccess(title: actionState.successTitle, message: container.displayName)
        } catch {
            let komodoError = KomodoError.from(error)
            self.loadError = komodoError
            InAppNotificationCenter.shared.reportFailure(actionState.failureActionName, error: komodoError)
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
            let message = containers.count == 1 ? containers[0].displayName : "\(containers.count) containers"
            InAppNotificationCenter.shared.showSuccess(title: actionState.successTitlePlural, message: message)
        } catch {
            let komodoError = KomodoError.from(error)
            self.loadError = komodoError
            InAppNotificationCenter.shared.reportFailure(actionState.failureActionName, error: komodoError)
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

    var successTitle: String {
        switch self {
        case .starting: "Container Started"
        case .stopping: "Container Stopped"
        case .restarting: "Container Restarted"
        case .killing: "Container Killed"
        case .deleting: "Container Deleted"
        }
    }

    var successTitlePlural: String {
        switch self {
        case .starting: "Containers Started"
        case .stopping: "Containers Stopped"
        case .restarting: "Containers Restarted"
        case .killing: "Containers Killed"
        case .deleting: "Containers Deleted"
        }
    }

    var failureActionName: String {
        switch self {
        case .starting: "Start Container"
        case .stopping: "Stop Container"
        case .restarting: "Restart Container"
        case .killing: "Kill Container"
        case .deleting: "Delete Container"
        }
    }
}
