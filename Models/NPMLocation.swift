@preconcurrency import Foundation

/// Location block within a proxy host (forwarding rules per path).
/// Schema: proxy-host-object.json locations[] — `additionalProperties: false`,
/// only `id`, `path`, `forward_scheme`, `forward_host`, `forward_port`, `forward_path`, `advanced_config` are valid.
struct NPMLocation: Sendable, Decodable, Encodable, Identifiable {
    let id: Int?
    let path: String
    let forward_scheme: String?
    let forward_host: String
    let forward_port: Int
    let forward_path: String?
    let advanced_config: String?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case forward_scheme
        case forward_host
        case forward_port
        case forward_path
        case advanced_config
    }
}

struct NPMLocationCreate: Sendable, Encodable {
    let path: String
    let forward_scheme: String
    let forward_host: String
    let forward_port: Int
    let forward_path: String?
    let advanced_config: String

    init(
        path: String = "/",
        forwardScheme: String = "http",
        forwardHost: String,
        forwardPort: Int,
        forwardPath: String? = nil,
        advancedConfig: String = ""
    ) {
        self.path = path
        self.forward_scheme = forwardScheme
        self.forward_host = forwardHost
        self.forward_port = forwardPort
        self.forward_path = forwardPath
        self.advanced_config = advancedConfig
    }
}
