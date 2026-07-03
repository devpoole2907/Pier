import Foundation

/// A snapshot of host-level resource usage for a Server, from `/read/GetSystemStats`.
/// Komodo has no per-container stats stream; this host-level snapshot is polled instead.
nonisolated struct ServerSystemStats: Sendable {
    let cpuPercent: Double
    let loadOne: Double
    let loadFive: Double
    let loadFifteen: Double
    let memUsedGB: Double
    let memTotalGB: Double
    let memFreeGB: Double
    let disks: [DiskStat]
    let networkIngressBytes: Double
    let networkEgressBytes: Double
    let refreshTS: Date

    var memPercent: Double {
        guard memTotalGB > 0 else { return 0 }
        return (memUsedGB / memTotalGB) * 100
    }

    private enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_perc"
        case loadAverage = "load_average"
        case memFreeGB = "mem_free_gb"
        case memUsedGB = "mem_used_gb"
        case memTotalGB = "mem_total_gb"
        case disks
        case networkIngressBytes = "network_ingress_bytes"
        case networkEgressBytes = "network_egress_bytes"
        case refreshTS = "refresh_ts"
    }

    private enum LoadAverageKeys: String, CodingKey {
        case one, five, fifteen
    }
}

extension ServerSystemStats: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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

        self.memFreeGB = try container.decodeIfPresent(Double.self, forKey: .memFreeGB) ?? 0
        self.memUsedGB = try container.decodeIfPresent(Double.self, forKey: .memUsedGB) ?? 0
        self.memTotalGB = try container.decodeIfPresent(Double.self, forKey: .memTotalGB) ?? 0
        self.disks = try container.decodeIfPresent([DiskStat].self, forKey: .disks) ?? []
        self.networkIngressBytes = try container.decodeIfPresent(Double.self, forKey: .networkIngressBytes) ?? 0
        self.networkEgressBytes = try container.decodeIfPresent(Double.self, forKey: .networkEgressBytes) ?? 0

        if let refreshMillis = try container.decodeIfPresent(Double.self, forKey: .refreshTS), refreshMillis > 0 {
            self.refreshTS = Date(timeIntervalSince1970: refreshMillis / 1000)
        } else {
            self.refreshTS = .now
        }
    }
}

/// A single mounted disk's usage, from `GetSystemStats.disks`.
nonisolated struct DiskStat: Sendable, Identifiable, Hashable {
    let mount: String
    let fileSystem: String
    let usedGB: Double
    let totalGB: Double

    var id: String { mount }

    var usedPercent: Double {
        guard totalGB > 0 else { return 0 }
        return (usedGB / totalGB) * 100
    }

    private enum CodingKeys: String, CodingKey {
        case mount
        case fileSystem = "file_system"
        case usedGB = "used_gb"
        case totalGB = "total_gb"
    }
}

extension DiskStat: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mount = try container.decodeIfPresent(String.self, forKey: .mount) ?? ""
        self.fileSystem = try container.decodeIfPresent(String.self, forKey: .fileSystem) ?? ""
        self.usedGB = try container.decodeIfPresent(Double.self, forKey: .usedGB) ?? 0
        self.totalGB = try container.decodeIfPresent(Double.self, forKey: .totalGB) ?? 0
    }
}
