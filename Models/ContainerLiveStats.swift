import Foundation

/// Inline per-container stats snapshot from `Container.stats`. Komodo has no streaming stats
/// endpoint; every field is a formatted string ready for display, with numeric values parsed
/// out for sorting/gauges where useful.
nonisolated struct ContainerLiveStats: Sendable, Hashable {
    let cpuPercRaw: String
    let memPercRaw: String
    let memUsage: String
    let netIO: String
    let blockIO: String
    let pids: String

    /// Parsed from `cpuPercRaw` by stripping the trailing `%`. `nil` if unparsable.
    var cpuPercent: Double? {
        Double(cpuPercRaw.trimmingCharacters(in: CharacterSet(charactersIn: "%")))
    }

    /// Parsed from `memPercRaw` by stripping the trailing `%`. `nil` if unparsable.
    var memPercent: Double? {
        Double(memPercRaw.trimmingCharacters(in: CharacterSet(charactersIn: "%")))
    }

    private enum CodingKeys: String, CodingKey {
        case cpuPercRaw = "cpu_perc"
        case memPercRaw = "mem_perc"
        case memUsage = "mem_usage"
        case netIO = "net_io"
        case blockIO = "block_io"
        case pids
    }
}

extension ContainerLiveStats: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cpuPercRaw = try container.decodeIfPresent(String.self, forKey: .cpuPercRaw) ?? ""
        self.memPercRaw = try container.decodeIfPresent(String.self, forKey: .memPercRaw) ?? ""
        self.memUsage = try container.decodeIfPresent(String.self, forKey: .memUsage) ?? ""
        self.netIO = try container.decodeIfPresent(String.self, forKey: .netIO) ?? ""
        self.blockIO = try container.decodeIfPresent(String.self, forKey: .blockIO) ?? ""
        self.pids = try container.decodeIfPresent(String.self, forKey: .pids) ?? ""
    }
}
