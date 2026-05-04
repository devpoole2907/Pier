import Foundation
import Observation

/// One row in the dashboard top-N tables.
struct DashboardRow: Identifiable, Sendable, Hashable {
    let containerID: String
    let displayName: String
    let history: [Double]
    let latestValue: Double

    var id: String { containerID }
}

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var totalCPUPercent: Double = 0
    private(set) var totalMemoryUsedBytes: Int64 = 0
    private(set) var totalMemoryLimitBytes: Int64 = 0
    private(set) var topByCPU: [DashboardRow] = []
    private(set) var topByMemory: [DashboardRow] = []
    private(set) var loadError: PortainerError?
    private(set) var isStreaming = false

    private let client: PortainerClient
    private let endpointID: Int
    @ObservationIgnored private var streamTasks: [String: Task<Void, Never>] = [:]
    private var histories: [String: [ContainerStats]] = [:]
    private var displayNames: [String: String] = [:]
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(client: PortainerClient, endpointID: Int) {
        self.client = client
        self.endpointID = endpointID
    }

    /// Begins streaming stats for every running container and refreshes the container list periodically.
    func start() {
        guard refreshTask == nil else { return }
        loadError = nil
        isStreaming = true
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshSubscriptions()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        for task in streamTasks.values {
            task.cancel()
        }
        streamTasks.removeAll()
        isStreaming = false
    }

    /// Compares the running container set with currently active streams; opens new streams for new
    /// containers and cancels streams for any that have stopped.
    private func refreshSubscriptions() async {
        do {
            let running = try await client.listContainers(endpointID: endpointID, includeStopped: false)
            let runningIDs = Set(running.map(\.id))

            for stale in streamTasks.keys where !runningIDs.contains(stale) {
                streamTasks[stale]?.cancel()
                streamTasks[stale] = nil
                histories[stale] = nil
                displayNames[stale] = nil
            }

            for container in running {
                displayNames[container.id] = container.displayName
                if streamTasks[container.id] == nil {
                    await subscribe(to: container)
                }
            }
            recomputeTops()
        } catch is CancellationError {
            return
        } catch let error as PortainerError {
            if case .network(let urlError) = error, urlError.code == .cancelled {
                return
            }
            self.loadError = error
        } catch {
            self.loadError = .serverError(code: -1, message: error.localizedDescription)
        }
    }

    private func subscribe(to container: Container) async {
        let stream = await client.streamStats(endpointID: endpointID, containerID: container.id)
        let id = container.id
        streamTasks[id] = Task { [weak self] in
            do {
                for try await sample in stream {
                    guard let self else { return }
                    self.record(sample, for: id)
                }
            } catch is CancellationError {
                return
            } catch let error as PortainerError where {
                if case .network(let urlError) = error {
                    return urlError.code == .cancelled
                }
                return false
            }() {
                return
            } catch {
                // Swallow per-container errors; surfacing them all would be noisy.
            }
        }
    }

    private func record(_ sample: ContainerStats, for containerID: String) {
        var current = histories[containerID, default: []]
        current.append(sample)
        if current.count > DesignSystem.Limits.maxStatsSamples {
            current.removeFirst(current.count - DesignSystem.Limits.maxStatsSamples)
        }
        histories[containerID] = current
        recomputeTops()
    }

    private func recomputeTops() {
        var totalCPU: Double = 0
        var totalMemUsed: Int64 = 0
        var totalMemLimit: Int64 = 0

        var byCPU: [DashboardRow] = []
        var byMem: [DashboardRow] = []

        for (containerID, samples) in histories {
            guard let latest = samples.last else { continue }
            totalCPU += latest.cpuPercent
            totalMemUsed += latest.memoryUsageBytes
            totalMemLimit += latest.memoryLimitBytes

            let cpuHistory = samples.map(\.cpuPercent)
            let memHistory = samples.map { Double($0.memoryUsageBytes) / 1_048_576 }

            let name = displayNames[containerID] ?? containerID.prefix(12).description
            byCPU.append(DashboardRow(
                containerID: containerID,
                displayName: name,
                history: cpuHistory,
                latestValue: latest.cpuPercent
            ))
            byMem.append(DashboardRow(
                containerID: containerID,
                displayName: name,
                history: memHistory,
                latestValue: Double(latest.memoryUsageBytes) / 1_048_576
            ))
        }

        self.totalCPUPercent = totalCPU
        self.totalMemoryUsedBytes = totalMemUsed
        self.totalMemoryLimitBytes = totalMemLimit
        self.topByCPU = byCPU.sorted { $0.latestValue > $1.latestValue }.prefix(5).map { $0 }
        self.topByMemory = byMem.sorted { $0.latestValue > $1.latestValue }.prefix(5).map { $0 }
    }

    deinit {
        refreshTask?.cancel()
        for task in streamTasks.values { task.cancel() }
    }
}
