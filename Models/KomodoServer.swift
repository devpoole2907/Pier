import SwiftUI

/// A Komodo Server - a Docker host managed by Komodo Core. Servers are first-class in Komodo
/// (not a hidden implementation detail): a single Core commonly manages several of them, each
/// with its own health state and system stats.
nonisolated struct KomodoServer: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let state: ServerState
    let region: String
    let publicIP: String?
    let version: String?
    let tags: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
        case info
    }

    private enum InfoKeys: String, CodingKey {
        case state
        case region
        case publicIP = "public_ip"
        case version
    }
}

extension KomodoServer: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        let info = try container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
        let rawState = try info.decodeIfPresent(String.self, forKey: .state)
        self.state = ServerState(rawState: rawState)
        self.region = try info.decodeIfPresent(String.self, forKey: .region) ?? ""
        self.publicIP = try info.decodeIfPresent(String.self, forKey: .publicIP)
        self.version = try info.decodeIfPresent(String.self, forKey: .version)
    }
}

/// Normalized server health state. Maps from Komodo's `info.state` / `GetServerState.status` strings.
nonisolated enum ServerState: String, Sendable, CaseIterable {
    case ok = "Ok"
    case notOk = "NotOk"
    case disabled = "Disabled"
    case unknown

    init(rawState: String?) {
        guard let rawState else {
            self = .unknown
            return
        }
        self = ServerState(rawValue: rawState) ?? .unknown
    }

    var label: String {
        switch self {
        case .ok: "Healthy"
        case .notOk: "Unreachable"
        case .disabled: "Disabled"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .notOk: .red
        case .disabled: .secondary
        case .unknown: .gray
        }
    }
}
