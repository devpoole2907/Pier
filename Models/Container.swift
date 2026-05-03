import Foundation

/// Container summary as returned by `GET /containers/json`. This is the lightweight form
/// suitable for list rows; full details come from `ContainerDetail`.
struct Container: Identifiable, Sendable, Decodable, Hashable {
    let id: String
    let names: [String]
    let image: String
    let imageID: String
    let command: String
    let created: Date
    let state: ContainerStatus
    let status: String
    let ports: [PortBinding]
    let labels: [String: String]

    /// Display name, with the leading slash Docker prepends stripped.
    var displayName: String {
        let raw = names.first ?? id.prefix(12).description
        return raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
    }

    /// Compose stack name, if this container belongs to one.
    var stackName: String? {
        labels["com.docker.compose.project"]
    }

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case names = "Names"
        case image = "Image"
        case imageID = "ImageID"
        case command = "Command"
        case created = "Created"
        case state = "State"
        case status = "Status"
        case ports = "Ports"
        case labels = "Labels"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.names = try container.decode([String].self, forKey: .names)
        self.image = try container.decode(String.self, forKey: .image)
        self.imageID = try container.decode(String.self, forKey: .imageID)
        self.command = try container.decode(String.self, forKey: .command)
        // Docker returns `Created` as a Unix timestamp (seconds).
        let createdSeconds = try container.decode(TimeInterval.self, forKey: .created)
        self.created = Date(timeIntervalSince1970: createdSeconds)
        let rawState = try container.decode(String.self, forKey: .state)
        self.state = ContainerStatus(rawState: rawState)
        self.status = try container.decode(String.self, forKey: .status)
        self.ports = try container.decodeIfPresent([PortBinding].self, forKey: .ports) ?? []
        self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }
}
