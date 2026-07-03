import Foundation
import Observation
import SwiftUI

/// A deployment is "active" when its container is up (running, or running-but-degraded).
/// Mirrors `Stack.isActive` since deployments share the same `StackState` model.
extension Deployment {
    var isActive: Bool {
        state == .running || state == .unhealthy
    }
}

/// Loads and drives lifecycle actions for Komodo deployments (single-container resources attached
/// to a Server). Shares the same load/action-state shape as `StacksViewModel` - deployments and
/// stacks are both Core-level resources with the same start/stop/restart/pause/destroy surface.
@MainActor
@Observable
final class DeploymentsViewModel {
    private(set) var deployments: [Deployment] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    private(set) var actionStatesByDeploymentID: [String: DeploymentActionState] = [:]

    /// Destroy is the one destructive deployment action - route it through a confirmation alert
    /// rather than executing immediately. Set by list-level UI; detail screens may instead confirm
    /// locally and call `destroy(_:)` directly.
    var pendingDestructiveAction: PendingDeploymentAction?

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.deployments = try await client.listDeployments().sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    // MARK: - Lifecycle

    func deploy(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .deploying) {
            try await self.client.deployDeployment(id: deployment.id)
        }
    }

    func pull(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .pulling) {
            try await self.client.pullDeployment(id: deployment.id)
        }
    }

    func start(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .starting) {
            try await self.client.startDeployment(id: deployment.id)
        }
    }

    func stop(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .stopping) {
            try await self.client.stopDeployment(id: deployment.id)
        }
    }

    func restart(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .restarting) {
            try await self.client.restartDeployment(id: deployment.id)
        }
    }

    func pause(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .pausing) {
            try await self.client.pauseDeployment(id: deployment.id)
        }
    }

    func unpause(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .unpausing) {
            try await self.client.unpauseDeployment(id: deployment.id)
        }
    }

    /// Destroys immediately - callers that need a confirmation step (detail screens with their
    /// own local alert) should confirm before calling this.
    func destroy(_ deployment: Deployment) async {
        await performAction(for: deployment, actionState: .destroying) {
            try await self.client.destroyDeployment(id: deployment.id)
        }
    }

    /// Queues a destroy for confirmation via `pendingDestructiveAction` (list-level alert flow).
    func requestDestroy(_ deployment: Deployment) {
        pendingDestructiveAction = PendingDeploymentAction(deployment: deployment)
    }

    func confirmDestructiveAction() async {
        guard let pending = pendingDestructiveAction else { return }
        pendingDestructiveAction = nil
        await destroy(pending.deployment)
    }

    func actionState(for deployment: Deployment) -> DeploymentActionState? {
        actionStatesByDeploymentID[deployment.id]
    }

    func isActionInProgress(for deployment: Deployment) -> Bool {
        actionState(for: deployment) != nil
    }

    private func performAction(
        for deployment: Deployment,
        actionState: DeploymentActionState,
        body: @escaping @Sendable () async throws -> Void
    ) async {
        actionStatesByDeploymentID[deployment.id] = actionState
        defer { actionStatesByDeploymentID[deployment.id] = nil }
        do {
            try await body()
            await load()
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }
}

struct PendingDeploymentAction: Identifiable {
    let deployment: Deployment

    var id: String { deployment.id }
}

/// Transient in-flight state for a deployment's row/detail while a lifecycle request is running.
enum DeploymentActionState: String, Sendable {
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

    /// Color used for the in-progress badge/spinner - independent of `Extensions/Color+Status.swift`
    /// so this surface doesn't need to touch shared container-status styling.
    var color: Color {
        switch self {
        case .deploying, .pulling, .starting: .green
        case .stopping, .restarting, .pausing, .unpausing: .yellow
        case .destroying: .red
        }
    }
}
