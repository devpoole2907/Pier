import Foundation
import Observation

@MainActor
@Observable
final class ContainerDetailViewModel {
    let serverID: String
    let containerID: String
    let initialName: String
    private(set) var detail: ContainerDetail?
    private(set) var loadError: KomodoError?
    /// Settable so the alert dismiss action can clear it.
    var actionError: KomodoError?
    private(set) var isLoading = false
    private(set) var isPerformingAction = false

    /// Inline live-stats snapshot (CPU%/mem/net/block IO/pids). Komodo has no per-container stats
    /// stream - this is refreshed by re-listing containers on `serverID` and picking out this
    /// container, driven by `runStatsPolling(every:)` from the detail view's polling loop.
    private(set) var liveStats: ContainerLiveStats?
    /// Small ring buffer of polled `cpuPercent` samples powering the detail sparkline, bounded by
    /// `DesignSystem.Limits.maxStatsSamples`.
    private(set) var cpuHistory: [Double] = []

    private let client: KomodoClient

    init(client: KomodoClient, serverID: String, containerID: String, initialName: String) {
        self.client = client
        self.serverID = serverID
        self.containerID = containerID
        self.initialName = initialName
    }

    var displayName: String {
        let raw = detail?.name ?? initialName
        return raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
    }

    /// Parsed environment variables from the inspect response.
    var environment: [EnvVar] {
        detail?.config.env.compactMap(EnvVar.init(rawString:)) ?? []
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.detail = try await client.inspectContainer(serverID: serverID, containerID: containerID)
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Refreshes the inline live-stats snapshot by re-listing containers on this container's
    /// server and matching by ID. Stats are supplementary to the main inspect load, so failures
    /// here are silently ignored rather than surfaced as a blocking error.
    func refreshStats() async {
        do {
            let containers = try await client.listContainers(serverID: serverID)
            guard let match = containers.first(where: { $0.id == containerID }) else { return }
            self.liveStats = match.stats
            if let cpuPercent = match.stats?.cpuPercent {
                cpuHistory.append(cpuPercent)
                if cpuHistory.count > DesignSystem.Limits.maxStatsSamples {
                    cpuHistory.removeFirst(cpuHistory.count - DesignSystem.Limits.maxStatsSamples)
                }
            }
        } catch {
            // Stats are supplementary; the main detail load surfaces connectivity problems.
        }
    }

    /// Long-running polling loop for the inline stats section. Always refreshes once immediately,
    /// then loops on `seconds` if provided (`nil` means the user has turned off auto-refresh).
    /// Drive this from the view's `.task(id:)` so cancellation flows naturally on view
    /// disappearance or interval change.
    func runStatsPolling(every seconds: TimeInterval?) async {
        await refreshStats()
        guard let seconds else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await refreshStats()
        }
    }

    func start() async {
        await performAction(successTitle: "Container Started", failureAction: "Start Container") {
            try await self.client.startContainer(serverID: self.serverID, containerID: self.containerID)
        }
    }
    func stop() async {
        await performAction(successTitle: "Container Stopped", failureAction: "Stop Container") {
            try await self.client.stopContainer(serverID: self.serverID, containerID: self.containerID)
        }
    }
    func restart() async {
        await performAction(successTitle: "Container Restarted", failureAction: "Restart Container") {
            try await self.client.restartContainer(serverID: self.serverID, containerID: self.containerID)
        }
    }
    func kill() async {
        // Komodo has no dedicated "kill" call; a SIGKILL stop with no grace period is the
        // equivalent of the old "kill" action.
        await performAction(successTitle: "Container Killed", failureAction: "Kill Container") {
            try await self.client.stopContainer(serverID: self.serverID, containerID: self.containerID, signal: "SIGKILL", time: 0)
        }
    }
    func delete() async {
        await performAction(successTitle: "Container Deleted", failureAction: "Delete Container") {
            try await self.client.destroyContainer(serverID: self.serverID, containerID: self.containerID)
        }
    }

    private func performAction(
        successTitle: String,
        failureAction: String,
        _ body: @escaping @Sendable () async throws -> Void
    ) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await body()
            self.actionError = nil
            await load()
            InAppNotificationCenter.shared.showSuccess(title: successTitle, message: displayName)
        } catch {
            let komodoError = KomodoError.from(error)
            self.actionError = komodoError
            InAppNotificationCenter.shared.reportFailure(failureAction, error: komodoError)
        }
    }

    /// Exposes `client` to the logs subview. Immutable on the actor side.
    var komodoClient: KomodoClient { client }
}
