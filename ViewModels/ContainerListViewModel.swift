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

    var filter: ContainerFilter = .all
    var searchText: String = ""

    private let client: PortainerClient
    private let endpointID: Int

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

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.containers = try await client.listContainers(endpointID: endpointID)
            self.loadError = nil
        } catch let error as PortainerError {
            self.loadError = error
        } catch {
            self.loadError = .serverError(code: -1, message: error.localizedDescription)
        }
    }

    func refresh() async {
        await load()
    }

    /// Long-running polling loop. Returns when the surrounding task is cancelled.
    /// Drive this from a view's `.task(id:)` so cancellation flows naturally on view disappearance
    /// or interval change.
    func runPolling(every seconds: TimeInterval) async {
        while !Task.isCancelled {
            await load()
            try? await Task.sleep(for: .seconds(seconds))
        }
    }

    // MARK: - Container actions

    func start(_ container: Container) async {
        await performAction { try await self.client.startContainer(endpointID: self.endpointID, containerID: container.id) }
    }

    func stop(_ container: Container) async {
        await performAction { try await self.client.stopContainer(endpointID: self.endpointID, containerID: container.id) }
    }

    func restart(_ container: Container) async {
        await performAction { try await self.client.restartContainer(endpointID: self.endpointID, containerID: container.id) }
    }

    func kill(_ container: Container) async {
        await performAction { try await self.client.killContainer(endpointID: self.endpointID, containerID: container.id) }
    }

    func delete(_ container: Container, force: Bool = true, removeVolumes: Bool = false) async {
        await performAction {
            try await self.client.deleteContainer(
                endpointID: self.endpointID,
                containerID: container.id,
                force: force,
                removeVolumes: removeVolumes
            )
        }
    }

    private func performAction(_ body: @escaping @Sendable () async throws -> Void) async {
        do {
            try await body()
            await load()
        } catch let error as PortainerError {
            self.loadError = error
        } catch {
            self.loadError = .serverError(code: -1, message: error.localizedDescription)
        }
    }
}
