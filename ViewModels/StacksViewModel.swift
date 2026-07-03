import Foundation
import Observation

@MainActor
@Observable
final class StacksViewModel {
    private(set) var stacks: [Stack] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    /// The stack's compose file, loaded on demand for the editor. `nil` once loaded means the
    /// stack has `files_on_host` set but Komodo couldn't return readable contents for it.
    private(set) var file: StackFileContent?
    private(set) var isLoadingFile = false

    /// Per-service info joined with live container state, from `listStackServices`. Loaded
    /// on demand by the detail view; failures are non-fatal since `stack.services` already
    /// carries a usable summary.
    private(set) var services: [StackService] = []

    private(set) var actionStatesByStackID: [String: StackActionState] = [:]

    var pendingDestructiveAction: PendingStackAction?

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.stacks = try await client.listStacks().sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    func loadFile(for stack: Stack) async {
        isLoadingFile = true
        defer { isLoadingFile = false }
        do {
            if let result = try await client.stackFile(stackID: stack.id) {
                self.file = StackFileContent(path: result.path, contents: result.contents)
            } else {
                self.file = nil
            }
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Writes the compose file back and updates local state to match on success.
    @discardableResult
    func saveFile(stackID: String, path: String, contents: String) async -> Bool {
        do {
            try await client.writeStackFile(stackID: stackID, path: path, contents: contents)
            self.file = StackFileContent(path: path, contents: contents)
            self.loadError = nil
            return true
        } catch {
            self.loadError = KomodoError.from(error)
            return false
        }
    }

    func loadServices(for stack: Stack) async {
        do {
            self.services = try await client.listStackServices(stackID: stack.id)
        } catch {
            // Optional enhancement over `stack.services` - keep the summary usable rather than
            // surfacing an error for a secondary fetch.
            self.services = []
        }
    }

    // MARK: - Lifecycle (single stack)

    func deploy(_ stack: Stack) async {
        await performAction(for: stack, actionState: .deploying) {
            try await self.client.deployStack(stackID: stack.id)
        }
    }

    func deployIfChanged(_ stack: Stack) async {
        await performAction(for: stack, actionState: .deploying) {
            try await self.client.deployStackIfChanged(stackID: stack.id)
        }
    }

    func pull(_ stack: Stack) async {
        await performAction(for: stack, actionState: .pulling) {
            try await self.client.pullStack(stackID: stack.id)
        }
    }

    func start(_ stack: Stack) async {
        await performAction(for: stack, actionState: .starting) {
            try await self.client.startStack(stackID: stack.id)
        }
    }

    func stop(_ stack: Stack) async {
        await performAction(for: stack, actionState: .stopping) {
            try await self.client.stopStack(stackID: stack.id)
        }
    }

    func restart(_ stack: Stack) async {
        await performAction(for: stack, actionState: .restarting) {
            try await self.client.restartStack(stackID: stack.id)
        }
    }

    func pause(_ stack: Stack) async {
        await performAction(for: stack, actionState: .pausing) {
            try await self.client.pauseStack(stackID: stack.id)
        }
    }

    func unpause(_ stack: Stack) async {
        await performAction(for: stack, actionState: .unpausing) {
            try await self.client.unpauseStack(stackID: stack.id)
        }
    }

    /// Destroy is the one destructive stack action - route it through a confirmation alert
    /// rather than executing immediately.
    func destroy(_ stack: Stack) {
        pendingDestructiveAction = PendingStackAction(stack: stack)
    }

    func confirmDestructiveAction() async {
        guard let pending = pendingDestructiveAction else { return }
        pendingDestructiveAction = nil
        await performAction(for: pending.stack, actionState: .destroying) {
            try await self.client.destroyStack(stackID: pending.stack.id)
        }
    }

    // MARK: - Lifecycle (bulk)

    func start(_ stacks: [Stack]) async {
        await performActions(stacks, actionState: .starting) { stack in
            try await self.client.startStack(stackID: stack.id)
        }
    }

    func stop(_ stacks: [Stack]) async {
        await performActions(stacks, actionState: .stopping) { stack in
            try await self.client.stopStack(stackID: stack.id)
        }
    }

    func restart(_ stacks: [Stack]) async {
        await performActions(stacks, actionState: .restarting) { stack in
            try await self.client.restartStack(stackID: stack.id)
        }
    }

    func destroy(_ stacks: [Stack]) async {
        await performActions(stacks, actionState: .destroying) { stack in
            try await self.client.destroyStack(stackID: stack.id)
        }
    }

    func actionState(for stack: Stack) -> StackActionState? {
        actionStatesByStackID[stack.id]
    }

    func isActionInProgress(for stack: Stack) -> Bool {
        actionState(for: stack) != nil
    }

    private func performAction(
        for stack: Stack,
        actionState: StackActionState,
        body: @escaping @Sendable () async throws -> Void
    ) async {
        actionStatesByStackID[stack.id] = actionState
        defer { actionStatesByStackID[stack.id] = nil }
        do {
            try await body()
            await load()
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    private func performActions(
        _ stacks: [Stack],
        actionState: StackActionState,
        operation: @escaping @Sendable (Stack) async throws -> Void
    ) async {
        for stack in stacks {
            actionStatesByStackID[stack.id] = actionState
        }
        defer {
            for stack in stacks {
                actionStatesByStackID[stack.id] = nil
            }
        }
        do {
            for stack in stacks {
                try await operation(stack)
            }
            await load()
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }
}

struct PendingStackAction: Identifiable {
    let stack: Stack

    var id: String { stack.id }
}

/// Transient in-flight state for a stack's row/detail while a lifecycle request is running.
enum StackActionState: String, Sendable {
    case deploying
    case pulling
    case starting
    case stopping
    case restarting
    case pausing
    case unpausing
    case destroying

    var displayName: String {
        switch self {
        case .deploying: "Deploying"
        case .pulling: "Pulling"
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .restarting: "Restarting"
        case .pausing: "Pausing"
        case .unpausing: "Resuming"
        case .destroying: "Destroying"
        }
    }

    var rowDetailText: String {
        "\(displayName) request in progress"
    }
}
