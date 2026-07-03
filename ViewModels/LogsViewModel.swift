import Foundation
import Observation

/// Komodo's `GetContainerLog` has no follow/stream endpoint - it always returns a snapshot of the
/// last `tail` lines. "Follow" is implemented here as a poll loop (`startFollowing`) that
/// re-fetches the snapshot on an interval and replaces the buffer wholesale, rather than
/// streaming and appending incremental chunks the way the previous Docker-management backend did.
@MainActor
@Observable
final class LogsViewModel {
    private(set) var lines: [LogLine] = []
    private(set) var isFollowing = false
    private(set) var loadError: KomodoError?

    var searchText: String = ""
    var tailCount: Int = 200

    private let client: KomodoClient
    private let serverID: String
    private let containerID: String
    @ObservationIgnored private var followTask: Task<Void, Never>?
    /// How often the follow loop re-polls the log snapshot.
    private let followInterval: Duration = .seconds(3)

    init(client: KomodoClient, serverID: String, containerID: String) {
        self.client = client
        self.serverID = serverID
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
            let log = try await client.containerLog(serverID: serverID, containerID: containerID, tail: tailCount)
            self.lines = Self.parseLines(from: log.combined)
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Loads more lines by increasing tail and reloading.
    func loadMore() async {
        tailCount += 200
        await loadInitial()
    }

    /// Starts the poll loop. Idempotent if already following.
    func startFollowing() async {
        guard followTask == nil else { return }
        isFollowing = true
        followTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollOnce()
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: self.followInterval)
            }
            self?.isFollowing = false
        }
    }

    func stopFollowing() {
        followTask?.cancel()
        followTask = nil
        isFollowing = false
    }

    private func pollOnce() async {
        do {
            let log = try await client.containerLog(serverID: serverID, containerID: containerID, tail: tailCount)
            self.lines = Self.parseLines(from: log.combined)
            self.loadError = nil
        } catch {
            self.loadError = KomodoError.from(error)
        }
    }

    /// Splits a combined log snapshot into numbered lines. Since every fetch replaces the buffer
    /// wholesale (rather than appending), numbering restarts from zero each time - stable line
    /// identity across polls isn't needed the way it was for the old incremental stream.
    private static func parseLines(from text: String) -> [LogLine] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { LogLine(number: $0.offset, text: String($0.element)) }
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
