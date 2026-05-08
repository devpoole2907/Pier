import Foundation
import Observation

@MainActor
@Observable
final class LogsViewModel {
    private(set) var lines: [LogLine] = []
    private(set) var isFollowing = false
    private(set) var loadError: PortainerError?

    var searchText: String = ""
    var tailCount: Int = 200

    private let client: PortainerClient
    private let endpointID: Int
    private let containerID: String
    @ObservationIgnored private var followTask: Task<Void, Never>?
    private var nextLineNumber = 0

    init(client: PortainerClient, endpointID: Int, containerID: String) {
        self.client = client
        self.endpointID = endpointID
        self.containerID = containerID
    }

    var visibleLines: [LogLine] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return lines }
        return lines.filter { $0.text.localizedStandardContains(trimmed) }
    }

    /// Joined string for the copy-to-clipboard button.
    var combinedText: String {
        lines.map(\.text).joined(separator: "\n")
    }

    /// Loads a single tail snapshot.
    func loadInitial() async {
        do {
            let raw = try await client.fetchLogs(endpointID: endpointID, containerID: containerID, tail: tailCount)
            self.lines = raw
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0) }
                .map { LogLine(number: nextNumber(), text: $0) }
            self.loadError = nil
        } catch {
            self.loadError = PortainerError.from(error)
        }
    }

    /// Loads more lines by increasing tail and reloading.
    func loadMore() async {
        tailCount += 200
        await loadInitial()
    }

    func startFollowing() async {
        guard followTask == nil else { return }
        isFollowing = true
        let stream = await client.streamLogs(endpointID: endpointID, containerID: containerID, tail: 0)
        followTask = Task { [weak self] in
            do {
                for try await chunk in stream {
                    guard let self else { return }
                    self.appendChunk(chunk)
                }
            } catch {
                self?.loadError = PortainerError.from(error)
            }
            self?.isFollowing = false
        }
    }

    func stopFollowing() {
        followTask?.cancel()
        followTask = nil
        isFollowing = false
    }

    private func appendChunk(_ chunk: String) {
        let split = chunk
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .filter { !$0.isEmpty }
        for text in split {
            lines.append(LogLine(number: nextNumber(), text: text))
        }
        // Trim to keep memory bounded; views can scroll back through the in-memory buffer up to this limit.
        if lines.count > DesignSystem.Limits.maxLogLines {
            lines.removeFirst(lines.count - DesignSystem.Limits.maxLogLines)
        }
    }

    private func nextNumber() -> Int {
        defer { nextLineNumber += 1 }
        return nextLineNumber
    }

    deinit {
        followTask?.cancel()
    }
}

/// One line in the log buffer. The number is needed because identical text lines must remain unique to SwiftUI.
struct LogLine: Identifiable, Sendable, Hashable {
    let number: Int
    let text: String

    var id: Int { number }
}
