import Foundation
import Observation

@MainActor
@Observable
final class StatsViewModel {
    private(set) var samples: [ContainerStats] = []
    private(set) var streamError: PortainerError?
    private(set) var isStreaming = false

    private let client: PortainerClient
    private let endpointID: Int
    private let containerID: String
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    init(client: PortainerClient, endpointID: Int, containerID: String) {
        self.client = client
        self.endpointID = endpointID
        self.containerID = containerID
    }

    /// Latest sample, if available - used to show the headline numbers.
    var latest: ContainerStats? { samples.last }

    /// Begins the stats stream. Idempotent if already running.
    func start() async {
        guard streamTask == nil else { return }
        isStreaming = true
        let stream = await client.streamStats(endpointID: endpointID, containerID: containerID)
        streamTask = Task { [weak self] in
            do {
                for try await sample in stream {
                    guard let self else { return }
                    self.append(sample)
                }
            } catch let error as PortainerError {
                self?.streamError = error
            } catch {
                self?.streamError = .serverError(code: -1, message: error.localizedDescription)
            }
            self?.isStreaming = false
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func append(_ sample: ContainerStats) {
        samples.append(sample)
        if samples.count > DesignSystem.Limits.maxStatsSamples {
            samples.removeFirst(samples.count - DesignSystem.Limits.maxStatsSamples)
        }
    }

    deinit {
        streamTask?.cancel()
    }
}
