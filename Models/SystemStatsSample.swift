import Foundation

/// A single point in a Server's historical stats series, from `/read/GetHistoricalServerStats`.
/// Used to drive optional Swift Charts history views; the live `GetSystemStats` gauges are the
/// must-have and do not depend on this model.
nonisolated struct SystemStatsSample: Sendable, Identifiable {
    let id = UUID()
    let ts: Date
    let cpuPercent: Double
    let loadOne: Double
    let loadFive: Double
    let loadFifteen: Double
    let memUsedGB: Double
    let memTotalGB: Double
    let diskUsedGB: Double
    let diskTotalGB: Double
    let networkIngressBytes: Double
    let networkEgressBytes: Double

    private enum CodingKeys: String, CodingKey {
        case ts
        case cpuPercent = "cpu_perc"
        case loadAverage = "load_average"
        case memUsedGB = "mem_used_gb"
        case memTotalGB = "mem_total_gb"
        case diskUsedGB = "disk_used_gb"
        case diskTotalGB = "disk_total_gb"
        case networkIngressBytes = "network_ingress_bytes"
        case networkEgressBytes = "network_egress_bytes"
    }

    private enum LoadAverageKeys: String, CodingKey {
        case one, five, fifteen
    }
}

extension SystemStatsSample: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let tsMillis = try container.decodeIfPresent(Double.self, forKey: .ts), tsMillis > 0 {
            self.ts = Date(timeIntervalSince1970: tsMillis / 1000)
        } else {
            self.ts = .now
        }

        self.cpuPercent = try container.decodeIfPresent(Double.self, forKey: .cpuPercent) ?? 0

        if let loadAverage = try? container.nestedContainer(keyedBy: LoadAverageKeys.self, forKey: .loadAverage) {
            self.loadOne = try loadAverage.decodeIfPresent(Double.self, forKey: .one) ?? 0
            self.loadFive = try loadAverage.decodeIfPresent(Double.self, forKey: .five) ?? 0
            self.loadFifteen = try loadAverage.decodeIfPresent(Double.self, forKey: .fifteen) ?? 0
        } else {
            self.loadOne = 0
            self.loadFive = 0
            self.loadFifteen = 0
        }

        self.memUsedGB = try container.decodeIfPresent(Double.self, forKey: .memUsedGB) ?? 0
        self.memTotalGB = try container.decodeIfPresent(Double.self, forKey: .memTotalGB) ?? 0
        self.diskUsedGB = try container.decodeIfPresent(Double.self, forKey: .diskUsedGB) ?? 0
        self.diskTotalGB = try container.decodeIfPresent(Double.self, forKey: .diskTotalGB) ?? 0
        self.networkIngressBytes = try container.decodeIfPresent(Double.self, forKey: .networkIngressBytes) ?? 0
        self.networkEgressBytes = try container.decodeIfPresent(Double.self, forKey: .networkEgressBytes) ?? 0
    }
}

/// `GetHistoricalServerStats` returns a paged wrapper: `{ stats: [...], next_page: Int? }`.
nonisolated struct HistoricalStatsResponse: Sendable {
    let stats: [SystemStatsSample]
    let nextPage: Int?

    private enum CodingKeys: String, CodingKey {
        case stats
        case nextPage = "next_page"
    }
}

extension HistoricalStatsResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.stats = try container.decodeIfPresent([SystemStatsSample].self, forKey: .stats) ?? []
        self.nextPage = try container.decodeIfPresent(Int.self, forKey: .nextPage)
    }
}
