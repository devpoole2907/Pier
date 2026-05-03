import Foundation
import Observation

@MainActor
@Observable
final class ContainerDetailViewModel {
    let containerID: String
    let initialName: String
    private(set) var detail: ContainerDetail?
    private(set) var loadError: PortainerError?
    /// Settable so the alert dismiss action can clear it.
    var actionError: PortainerError?
    private(set) var isLoading = false
    private(set) var isPerformingAction = false

    private let client: PortainerClient
    private let endpointID: Int

    init(client: PortainerClient, endpointID: Int, containerID: String, initialName: String) {
        self.client = client
        self.endpointID = endpointID
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
            self.detail = try await client.inspectContainer(endpointID: endpointID, containerID: containerID)
            self.loadError = nil
        } catch let error as PortainerError {
            self.loadError = error
        } catch {
            self.loadError = .serverError(code: -1, message: error.localizedDescription)
        }
    }

    func start() async { await performAction { try await self.client.startContainer(endpointID: self.endpointID, containerID: self.containerID) } }
    func stop() async { await performAction { try await self.client.stopContainer(endpointID: self.endpointID, containerID: self.containerID) } }
    func restart() async { await performAction { try await self.client.restartContainer(endpointID: self.endpointID, containerID: self.containerID) } }
    func kill() async { await performAction { try await self.client.killContainer(endpointID: self.endpointID, containerID: self.containerID) } }
    func delete(removeVolumes: Bool = false) async {
        await performAction {
            try await self.client.deleteContainer(
                endpointID: self.endpointID,
                containerID: self.containerID,
                force: true,
                removeVolumes: removeVolumes
            )
        }
    }

    private func performAction(_ body: @escaping @Sendable () async throws -> Void) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await body()
            self.actionError = nil
            await load()
        } catch let error as PortainerError {
            self.actionError = error
        } catch {
            self.actionError = .serverError(code: -1, message: error.localizedDescription)
        }
    }

    /// Make `client` and `endpointID` accessible to the stats/logs subviews. Both are immutable on the actor side.
    var portainerClient: PortainerClient { client }
    var resolvedEndpointID: Int { endpointID }
}
