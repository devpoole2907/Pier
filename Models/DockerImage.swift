import Foundation

/// A Docker image as returned by `/read/ListDockerImages`.
/// Named `DockerImage` (not `Image`) to avoid colliding with `SwiftUI.Image`.
nonisolated struct DockerImage: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let tags: [String]
    let created: Date
    let size: Int64
    let inUse: Bool

    /// Best human-readable label: first non-`<none>` tag, else the short repo/tag `name`
    /// Komodo already supplies, else a truncated digest.
    var displayName: String {
        if let tag = tags.first(where: { $0 != "<none>:<none>" && !$0.isEmpty }) {
            return tag
        }
        if name.hasPrefix("sha256:") {
            return "untagged@\(name.replacingOccurrences(of: "sha256:", with: "").prefix(12))"
        }
        return name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
        case created
        case size
        case inUse = "in_use"
    }
}

extension DockerImage: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let createdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .created) ?? 0
        self.created = Date(timeIntervalSince1970: createdSeconds)
        self.size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        self.inUse = try container.decodeIfPresent(Bool.self, forKey: .inUse) ?? false
    }
}
