import Foundation

/// A log snapshot from `/read/GetContainerLog` or `/read/SearchContainerLog`. Komodo has no log
/// follow stream; "Follow" in the UI becomes a poll loop that re-fetches and replaces this
/// snapshot on an interval.
nonisolated struct ContainerLog: Sendable {
    let stdout: String
    let stderr: String

    /// stdout and stderr interleaved for display, in that order.
    var combined: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey {
        case stdout
        case stderr
    }
}

extension ContainerLog: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.stdout = try container.decodeIfPresent(String.self, forKey: .stdout) ?? ""
        self.stderr = try container.decodeIfPresent(String.self, forKey: .stderr) ?? ""
    }
}
