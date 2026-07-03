import Foundation
import Observation

/// Backs the top-level Dashboard - a cross-service overview (Swift Charts included) that sits
/// above the per-service screens (the detailed Servers list lives under the More tab via
/// `ServersDashboardView`). Today it only has a "Servers" section covering Komodo host health,
/// but the view model is written so a later "Proxy/NPM" or "SSH" section can be added as its own
/// independent load path without disturbing this one - see `ServersSection` in
/// `Views/Dashboard/` for how the data here is consumed.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var servers: [KomodoServer] = []
    private(set) var stats: [String: ServerSystemStats] = [:]
    private(set) var history: [String: [SystemStatsSample]] = [:]
    private(set) var isLoading = false
    private(set) var loadError: KomodoError?

    private let client: KomodoClient

    /// Granularity passed to `GetHistoricalServerStats`. Komodo's stats-history endpoint takes a
    /// `Timelength` value serialized as a lowercase hyphenated string - Komodo's serde renames are
    /// `"1-sec"`, `"5-sec"`, `"1-min"`, `"5-min"`, `"15-min"`, `"1-hr"`, `"1-day"`, `"1-wk"`, ...
    /// (`HistoricalStatsBody.granularity` in `Services/KomodoRequests.swift` is a bare `String`).
    /// `"1-hr"` is chosen as a granularity that covers several days of "recent" history per page.
    /// If this value ever turns out to be wrong, the request simply fails and `loadHistory` swallows
    /// that per-server (empty history -> the history card's own empty state), so it can't take down
    /// the rest of the dashboard. Verify against the live Komodo instance.
    static let defaultGranularity = "1-hr"

    init(client: KomodoClient) {
        self.client = client
    }

    /// Servers Komodo reports as reachable. Only these are polled for live/historical stats -
    /// unreachable or disabled servers have nothing to chart.
    var reachableServers: [KomodoServer] {
        servers.filter { $0.state == .ok }
    }

    var healthyCount: Int { reachableServers.count }
    var unreachableCount: Int { servers.count - healthyCount }

    /// Mean live CPU% across reachable servers, or `nil` if none have reported stats yet.
    var averageCPUPercent: Double? {
        average(reachableServers.compactMap { stats[$0.id]?.cpuPercent })
    }

    /// Mean live memory% across reachable servers, or `nil` if none have reported stats yet.
    var averageMemoryPercent: Double? {
        average(reachableServers.compactMap { stats[$0.id]?.memPercent })
    }

    func stats(for server: KomodoServer) -> ServerSystemStats? {
        stats[server.id]
    }

    func history(for server: KomodoServer) -> [SystemStatsSample] {
        history[server.id] ?? []
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let servers = try await client.listServers()
            self.servers = servers
            self.loadError = nil
            async let statsLoad: Void = loadStats(for: servers)
            async let historyLoad: Void = loadHistory(for: servers)
            _ = await (statsLoad, historyLoad)
        } catch let error as KomodoError {
            self.loadError = error
        } catch {
            self.loadError = .network(error as? URLError ?? URLError(.unknown))
        }
    }

    /// Fetches live host stats for every reachable server concurrently, mirroring
    /// `ServersDashboardViewModel.loadStats`.
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
        for (id, sample) in results {
            stats[id] = sample
        }
    }

    /// Fetches the CPU/memory time series for every reachable server concurrently. Failures (bad
    /// granularity string, transient network error, brand-new server with no history yet) resolve
    /// to an empty array for that server rather than failing the whole dashboard load.
    private func loadHistory(for servers: [KomodoServer]) async {
        let reachable = servers.filter { $0.state == .ok }
        let granularity = Self.defaultGranularity
        let results = await withTaskGroup(of: (String, [SystemStatsSample]).self) { group in
            for server in reachable {
                group.addTask { [client] in
                    let samples = (try? await client.historicalStats(
                        serverID: server.id,
                        granularity: granularity
                    )) ?? []
                    return (server.id, samples.sorted { $0.ts < $1.ts })
                }
            }
            var collected: [String: [SystemStatsSample]] = [:]
            for await (id, samples) in group {
                collected[id] = samples
            }
            return collected
        }
        for (id, samples) in results {
            history[id] = samples
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
