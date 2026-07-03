import Foundation

/// Container summary as returned by `/read/ListDockerContainers` (or `ListAllDockerContainers`).
/// This is the lightweight form suitable for list rows; full details come from `ContainerDetail`.
/// Komodo inlines a live stats snapshot directly on the list item rather than requiring a
/// separate streaming stats call.
nonisolated struct Container: Identifiable, Sendable, Hashable {
    let id: String
    let serverID: String
    let name: String
    let image: String
    let imageID: String
    let created: Date
    let state: ContainerStatus
    let status: String
    let networkMode: String?
    let networks: [String]
    let ports: [PortBinding]
    let stats: ContainerLiveStats?

    /// Komodo already strips the leading slash Docker prepends, so this is just `name`.
    var displayName: String { name }

    /// Compose stack name. Not present on the list item itself (Komodo joins stacks
    /// separately via `ListStacks`/`ListStackServices`); grouping in the UI is done by
    /// server instead. Kept for source compatibility with call sites that still reference it.
    var stackName: String? { nil }

    static func == (lhs: Container, rhs: Container) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case serverID = "server_id"
        case name
        case image
        case imageID = "image_id"
        case created
        case state
        case status
        case networkMode = "network_mode"
        case networks
        case ports
        case stats
    }
}

extension Container: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.serverID = try container.decodeIfPresent(String.self, forKey: .serverID) ?? ""
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""
        self.imageID = try container.decodeIfPresent(String.self, forKey: .imageID) ?? ""

        // Komodo returns `created` as a Unix timestamp in seconds.
        let createdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .created) ?? 0
        self.created = Date(timeIntervalSince1970: createdSeconds)

        let rawState = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        self.state = ContainerStatus(rawState: rawState)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.networkMode = try container.decodeIfPresent(String.self, forKey: .networkMode)
        self.networks = try container.decodeIfPresent([String].self, forKey: .networks) ?? []
        self.ports = try container.decodeIfPresent([PortBinding].self, forKey: .ports) ?? []
        self.stats = try container.decodeIfPresent(ContainerLiveStats.self, forKey: .stats)
    }
}
