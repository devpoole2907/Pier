import Foundation

/// A single published port on a container.
struct PortBinding: Sendable, Decodable, Hashable, Identifiable {
    let ip: String?
    let privatePort: Int
    let publicPort: Int?
    let type: String

    /// Stable identifier for SwiftUI lists.
    var id: String {
        "\(ip ?? "*"):\(publicPort ?? 0)->\(privatePort)/\(type)"
    }

    /// Human-readable summary for list rows, e.g. "8080→80/tcp".
    var displayString: String {
        if let publicPort {
            "\(publicPort)→\(privatePort)/\(type)"
        } else {
            "\(privatePort)/\(type)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case ip = "IP"
        case privatePort = "PrivatePort"
        case publicPort = "PublicPort"
        case type = "Type"
    }
}
