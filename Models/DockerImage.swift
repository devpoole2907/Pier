import Foundation

/// A Docker image as returned by `GET /images/json`.
/// Named `DockerImage` (not `Image`) to avoid colliding with `SwiftUI.Image`.
struct DockerImage: Identifiable, Sendable, Decodable, Hashable {
    let id: String
    let repoTags: [String]
    let repoDigests: [String]
    let created: Date
    let size: Int64
    let virtualSize: Int64?
    let labels: [String: String]
    let containers: Int

    /// Best human-readable label, falling back to the truncated image ID.
    var displayName: String {
        repoTags.first(where: { $0 != "<none>:<none>" }) ?? "untagged@\(id.replacingOccurrences(of: "sha256:", with: "").prefix(12))"
    }

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case repoTags = "RepoTags"
        case repoDigests = "RepoDigests"
        case created = "Created"
        case size = "Size"
        case virtualSize = "VirtualSize"
        case labels = "Labels"
        case containers = "Containers"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.repoTags = try container.decodeIfPresent([String].self, forKey: .repoTags) ?? []
        self.repoDigests = try container.decodeIfPresent([String].self, forKey: .repoDigests) ?? []
        let createdSeconds = try container.decode(TimeInterval.self, forKey: .created)
        self.created = Date(timeIntervalSince1970: createdSeconds)
        self.size = try container.decode(Int64.self, forKey: .size)
        self.virtualSize = try container.decodeIfPresent(Int64.self, forKey: .virtualSize)
        self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        self.containers = try container.decodeIfPresent(Int.self, forKey: .containers) ?? 0
    }
}
