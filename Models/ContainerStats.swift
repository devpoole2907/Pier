import Foundation

/// A single sample from the Docker stats stream.
///
/// Docker's stats endpoint returns a heavyweight JSON blob; we extract just the few fields needed to
/// drive the UI (CPU%, memory usage/limit, network rx/tx). CPU% is computed here once at decode
/// time using the standard Docker formula so the view layer can stay ignorant of the maths.
struct ContainerStats: Sendable, Identifiable {
    /// Per-sample identifier so SwiftUI charts can key by it. Made up from `read` (timestamp).
    let id: Date
    let read: Date
    let cpuPercent: Double
    let memoryUsageBytes: Int64
    let memoryLimitBytes: Int64
    let networkRxBytes: Int64
    let networkTxBytes: Int64

    var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0 }
        return (Double(memoryUsageBytes) / Double(memoryLimitBytes)) * 100
    }

    private enum CodingKeys: String, CodingKey {
        case read
        case cpuStats = "cpu_stats"
        case precpuStats = "precpu_stats"
        case memoryStats = "memory_stats"
        case networks
    }

    private enum CPUKeys: String, CodingKey {
        case cpuUsage = "cpu_usage"
        case systemCPUUsage = "system_cpu_usage"
        case onlineCPUs = "online_cpus"
    }

    private enum CPUUsageKeys: String, CodingKey {
        case totalUsage = "total_usage"
        case percpuUsage = "percpu_usage"
    }

    private enum MemoryKeys: String, CodingKey {
        case usage
        case limit
    }

    private enum NetworkKeys: String, CodingKey {
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
    }

}

extension ContainerStats: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: CodingKeys.self)

        let readString = try root.decode(String.self, forKey: .read)
        let parsedRead = (try? Date(readString, strategy: .iso8601)) ?? .now
        self.read = parsedRead
        self.id = parsedRead

        // CPU calculation: Docker docs formula.
        let cpuStats = try root.nestedContainer(keyedBy: CPUKeys.self, forKey: .cpuStats)
        let precpuStats = try root.nestedContainer(keyedBy: CPUKeys.self, forKey: .precpuStats)

        let cpuUsage = try cpuStats.nestedContainer(keyedBy: CPUUsageKeys.self, forKey: .cpuUsage)
        let preCpuUsage = try precpuStats.nestedContainer(keyedBy: CPUUsageKeys.self, forKey: .cpuUsage)

        let totalUsage = try cpuUsage.decodeIfPresent(Int64.self, forKey: .totalUsage) ?? 0
        let preTotalUsage = try preCpuUsage.decodeIfPresent(Int64.self, forKey: .totalUsage) ?? 0
        let systemUsage = try cpuStats.decodeIfPresent(Int64.self, forKey: .systemCPUUsage) ?? 0
        let preSystemUsage = try precpuStats.decodeIfPresent(Int64.self, forKey: .systemCPUUsage) ?? 0
        let onlineCPUs = try cpuStats.decodeIfPresent(Int.self, forKey: .onlineCPUs) ?? {
            let percpu = try? cpuUsage.decodeIfPresent([Int64].self, forKey: .percpuUsage)
            return percpu?.count ?? 1
        }()

        let cpuDelta = Double(totalUsage - preTotalUsage)
        let systemDelta = Double(systemUsage - preSystemUsage)

        if systemDelta > 0, cpuDelta > 0 {
            self.cpuPercent = (cpuDelta / systemDelta) * Double(onlineCPUs) * 100
        } else {
            self.cpuPercent = 0
        }

        // Memory.
        let memoryStats = try root.nestedContainer(keyedBy: MemoryKeys.self, forKey: .memoryStats)
        self.memoryUsageBytes = try memoryStats.decodeIfPresent(Int64.self, forKey: .usage) ?? 0
        self.memoryLimitBytes = try memoryStats.decodeIfPresent(Int64.self, forKey: .limit) ?? 0

        // Network: aggregate across all interfaces.
        var totalRx: Int64 = 0
        var totalTx: Int64 = 0
        if let networks = try? root.decodeIfPresent([String: NetworkBytes].self, forKey: .networks) {
            for (_, bytes) in networks {
                totalRx += bytes.rxBytes
                totalTx += bytes.txBytes
            }
        }
        self.networkRxBytes = totalRx
        self.networkTxBytes = totalTx
    }

    struct NetworkBytes: Sendable {
        let rxBytes: Int64
        let txBytes: Int64

        private enum CodingKeys: String, CodingKey {
            case rxBytes = "rx_bytes"
            case txBytes = "tx_bytes"
        }
    }
}

extension ContainerStats.NetworkBytes: Decodable {}
