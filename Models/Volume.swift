import Foundation

/// A Docker volume entry.
struct Volume: Identifiable, Sendable, Hashable {
    let name: String
    let driver: String
    let mountpoint: String
    let createdAt: Date?
    let scope: String
    let labels: [String: String]

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case driver = "Driver"
        case mountpoint = "Mountpoint"
        case createdAt = "CreatedAt"
        case scope = "Scope"
        case labels = "Labels"
    }

}

extension Volume: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.driver = try container.decodeIfPresent(String.self, forKey: .driver) ?? "local"
        self.mountpoint = try container.decodeIfPresent(String.self, forKey: .mountpoint) ?? ""
        self.scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? "local"
        self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        if let createdRaw = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = try? Date(createdRaw, strategy: .iso8601)
        } else {
            self.createdAt = nil
        }
    }
}

/// `GET /volumes` returns `{ "Volumes": [...] }`.
struct VolumeListResponse: Sendable {
    let volumes: [Volume]

    private enum CodingKeys: String, CodingKey {
        case volumes = "Volumes"
    }

}

extension VolumeListResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.volumes = try container.decodeIfPresent([Volume].self, forKey: .volumes) ?? []
    }
}
