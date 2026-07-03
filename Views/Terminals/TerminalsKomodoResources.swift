import Foundation
import Observation

/// Holds the live Komodo resource lists used to populate `TerminalsTab`'s Komodo sections and
/// its "+" config sheets. Servers are already cached on `HostManager`; containers, stacks, and
/// deployments aren't cached anywhere else, so this fetches and holds them for the Terminals tab.
@MainActor
@Observable
final class TerminalsKomodoResources {
    private(set) var containers: [Container] = []
    private(set) var stacks: [Stack] = []
    private(set) var deployments: [Deployment] = []
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    /// Fetches containers/stacks/deployments across all servers under the given client.
    func load(client: KomodoClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let containersTask = client.listContainers(serverID: nil)
            async let stacksTask = client.listStacks()
            async let deploymentsTask = client.listDeployments()
            let (containers, stacks, deployments) = try await (containersTask, stacksTask, deploymentsTask)
            self.containers = containers
            self.stacks = stacks
            self.deployments = deployments
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Drops any cached resources — used when there's no active Komodo host.
    func clear() {
        containers = []
        stacks = []
        deployments = []
        loadError = nil
    }
}
