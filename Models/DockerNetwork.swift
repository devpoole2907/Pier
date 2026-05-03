import Foundation

/// A Docker network. Named `DockerNetwork` to avoid colliding with Foundation's `Network` framework.
struct DockerNetwork: Identifiable, Sendable, Decodable, Hashable {
    let id: String
    let name: String
    let driver: String
    let scope: String
    let internal_: Bool
    let attachable: Bool
    let labels: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case driver = "Driver"
        case scope = "Scope"
        case internal_ = "Internal"
        case attachable = "Attachable"
        case labels = "Labels"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.driver = try container.decodeIfPresent(String.self, forKey: .driver) ?? ""
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? ""
        self.internal_ = try container.decodeIfPresent(Bool.self, forKey: .internal_) ?? false
        self.attachable = try container.decodeIfPresent(Bool.self, forKey: .attachable) ?? false
        self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }
}
