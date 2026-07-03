import Foundation

/// A Docker network, from `/read/ListDockerNetworks`. Named `DockerNetwork` to avoid colliding
/// with Foundation's `Network` framework. Note: unlike the raw Docker API (which uses
/// `PascalCase` keys), Komodo serializes its own `snake_case` network summary type.
nonisolated struct DockerNetwork: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let driver: String
    let scope: String
    let internal_: Bool
    let attachable: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case driver
        case scope
        case internal_ = "internal"
        case attachable
    }
}

extension DockerNetwork: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try container.decode(String.self, forKey: .name)
        self.driver = try container.decodeIfPresent(String.self, forKey: .driver) ?? ""
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? ""
        self.internal_ = try container.decodeIfPresent(Bool.self, forKey: .internal_) ?? false
        self.attachable = try container.decodeIfPresent(Bool.self, forKey: .attachable) ?? false
    }
}
