import Foundation

/// A Komodo deployment - a single-container Core-level resource attached to a Server, from
/// `/read/ListDeployments`. Shares the same UI/lifecycle patterns as Stacks. Empty on many
/// setups (most users run Stacks instead) but implemented for completeness.
nonisolated struct Deployment: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let serverID: String
    let state: StackState
    let image: String?
    let updateAvailable: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case info
    }

    private enum InfoKeys: String, CodingKey {
        case serverID = "server_id"
        case state
        case image
        case updateAvailable = "update_available"
    }
}

extension Deployment: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""

        let info = try container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
        self.serverID = try info.decodeIfPresent(String.self, forKey: .serverID) ?? ""
        let rawState = try info.decodeIfPresent(String.self, forKey: .state)
        self.state = StackState(rawState: rawState)
        self.image = try info.decodeIfPresent(String.self, forKey: .image)
        self.updateAvailable = try info.decodeIfPresent(Bool.self, forKey: .updateAvailable) ?? false
    }
}
