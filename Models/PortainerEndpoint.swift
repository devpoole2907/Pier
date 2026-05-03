import Foundation

/// A Portainer "endpoint" - a Docker environment connected to the Portainer instance.
/// Most home setups have exactly one, but the API is plural-aware.
struct PortainerEndpoint: Identifiable, Sendable, Decodable, Hashable {
    let id: Int
    let name: String
    let type: Int
    let status: Int
    let url: String

    /// Convenience: a connected/running Docker endpoint has status == 1.
    var isUp: Bool { status == 1 }

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case status = "Status"
        case url = "URL"
    }
}
