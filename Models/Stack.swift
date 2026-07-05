import SwiftUI

/// A Komodo-managed compose stack as returned by `/read/ListStacks`. Stacks are Core-level
/// resources explicitly attached to a Server (rather than living implicitly on a single hidden
/// environment).
nonisolated struct Stack: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let serverID: String
    let state: StackState
    let statusText: String
    let services: [StackServiceInfo]
    let filesOnHost: Bool
    let tags: [String]
    let updatePolicy: StackUpdatePolicy

    /// True if any service in the stack has an update available.
    var updateAvailable: Bool {
        services.contains(where: \.updateAvailable)
    }

    /// A stack is "active" when its containers are up (running, or running-but-degraded).
    var isActive: Bool {
        state == .running || state == .unhealthy
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tags
        case info
        case config
    }

    private enum ConfigKeys: String, CodingKey {
        case pollForUpdates = "poll_for_updates"
        case autoUpdate = "auto_update"
        case autoUpdateAllServices = "auto_update_all_services"
    }

    private enum InfoKeys: String, CodingKey {
        case serverID = "server_id"
        case filesOnHost = "files_on_host"
        case state
        case status
        case services
    }
}

extension Stack: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []

        let info = try container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
        self.serverID = try info.decodeIfPresent(String.self, forKey: .serverID) ?? ""
        self.filesOnHost = try info.decodeIfPresent(Bool.self, forKey: .filesOnHost) ?? false
        let rawState = try info.decodeIfPresent(String.self, forKey: .state)
        self.state = StackState(rawState: rawState)
        self.statusText = try info.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.services = try info.decodeIfPresent([StackServiceInfo].self, forKey: .services) ?? []

        if let config = try? container.nestedContainer(keyedBy: ConfigKeys.self, forKey: .config) {
            self.updatePolicy = StackUpdatePolicy(
                pollForUpdates: try config.decodeIfPresent(Bool.self, forKey: .pollForUpdates) ?? false,
                autoUpdate: try config.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? false,
                autoUpdateAllServices: try config.decodeIfPresent(Bool.self, forKey: .autoUpdateAllServices) ?? false
            )
        } else {
            self.updatePolicy = .disabled
        }
    }
}

nonisolated struct StackUpdatePolicy: Sendable, Hashable {
    let pollForUpdates: Bool
    let autoUpdate: Bool
    let autoUpdateAllServices: Bool

    static let disabled = StackUpdatePolicy(
        pollForUpdates: false,
        autoUpdate: false,
        autoUpdateAllServices: false
    )
}

/// Per-service summary embedded in a `Stack` list item (`info.services`).
nonisolated struct StackServiceInfo: Sendable, Hashable, Identifiable {
    let service: String
    let image: String
    let updateAvailable: Bool

    var id: String { service }

    private enum CodingKeys: String, CodingKey {
        case service
        case image
        case updateAvailable = "update_available"
    }
}

extension StackServiceInfo: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.service = try container.decodeIfPresent(String.self, forKey: .service) ?? ""
        self.image = try container.decodeIfPresent(String.self, forKey: .image) ?? ""
        self.updateAvailable = try container.decodeIfPresent(Bool.self, forKey: .updateAvailable) ?? false
    }
}

/// Normalized stack health state, from `info.state`.
nonisolated enum StackState: String, Sendable, CaseIterable {
    case running
    case stopped
    case unhealthy
    case deploying
    case down
    case unknown

    init(rawState: String?) {
        guard let rawState else {
            self = .unknown
            return
        }
        self = StackState(rawValue: rawState.lowercased()) ?? .unknown
    }

    var label: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .unhealthy: "Unhealthy"
        case .deploying: "Deploying"
        case .down: "Down"
        case .unknown: "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .running: .green
        case .stopped: .secondary
        case .unhealthy: .red
        case .deploying: .orange
        case .down: .gray
        case .unknown: .gray
        }
    }
}
