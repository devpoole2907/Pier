import Foundation

/// A Docker volume entry, from `/read/ListDockerVolumes`. Note: unlike the raw Docker API
/// (which uses `PascalCase` keys), Komodo serializes its own `snake_case` volume summary type.
nonisolated struct Volume: Identifiable, Sendable, Hashable {
    let name: String
    let driver: String
    let mountpoint: String
    let createdAt: Date?
    let scope: String
    let inUse: Bool

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case driver
        case mountpoint
        case createdAt = "created"
        case scope
        case inUse = "in_use"
    }
}

extension Volume: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.driver = try container.decodeIfPresent(String.self, forKey: .driver) ?? "local"
        self.mountpoint = try container.decodeIfPresent(String.self, forKey: .mountpoint) ?? ""
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? "local"
        self.inUse = try container.decodeIfPresent(Bool.self, forKey: .inUse) ?? false
        if let createdRaw = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = try? Date(createdRaw, strategy: .iso8601)
        } else {
            self.createdAt = nil
        }
    }
}
