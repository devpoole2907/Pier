import Foundation
import Observation

/// Backs the Servers dashboard - the Komodo-native replacement for the old container-aggregate
/// "Stats" screen. Komodo Servers are first-class: each connects to a Periphery agent that reports
/// host-level system stats (CPU, load, memory, disk, network). There is no per-container stats
/// stream in Komodo, so we poll `GetSystemStats` per server instead.
@MainActor
@Observable
final class ServersDashboardViewModel {
    private(set) var servers: [KomodoServer] = []
    private(set) var stats: [String: ServerSystemStats] = [:]
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    private let client: KomodoClient

    init(client: KomodoClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let servers = try await client.listServers()
            self.servers = servers
            self.loadError = nil
            await loadStats(for: servers)
        } catch let error as KomodoError {
            self.loadError = error
        } catch {
            self.loadError = .network(error as? URLError ?? URLError(.unknown))
        }
    }

    func stats(for server: KomodoServer) -> ServerSystemStats? {
        stats[server.id]
    }

    /// Fetches host stats for every reachable server concurrently. Unreachable/disabled servers are
    /// skipped - their rows show the state badge without metrics.
    private func loadStats(for servers: [KomodoServer]) async {
        let reachable = servers.filter { $0.state == .ok }
        let results = await withTaskGroup(of: (String, ServerSystemStats?).self) { group in
            for server in reachable {
                group.addTask { [client] in
                    (server.id, try? await client.systemStats(serverID: server.id))
                }
            }
            var collected: [String: ServerSystemStats] = [:]
            for await (id, sample) in group {
                collected[id] = sample
            }
            return collected
        }
        // Preserve any prior stats for servers that momentarily failed this refresh - only
        // successful fetches make it into `results` (failed ones were dropped from the dictionary).
        for (id, sample) in results {
            stats[id] = sample
        }
    }
}
