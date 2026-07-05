import Foundation

/// Full stack document as returned by `/read/GetStack`. Carries the compose file contents
/// used by the stack editor, in addition to the summary fields also present on the `Stack`
/// list item.
nonisolated struct StackDetail: Identifiable, Sendable {
    let id: String
    let name: String
    let serverID: String
    let filesOnHost: Bool
    let files: [StackFileContent]
    let deployedServices: [String]
    let latestServices: [String]
    let updatePolicy: StackUpdatePolicy

    /// The compose file to show in the editor. Usually there is exactly one.
    var primaryFile: StackFileContent? { files.first }

    private enum CodingKeys: String, CodingKey {
        case oid = "_id"
        case name
        case config
        case info
    }

    private enum OIDKeys: String, CodingKey {
        case oid = "$oid"
    }

    private enum ConfigKeys: String, CodingKey {
        case serverID = "server_id"
        case pollForUpdates = "poll_for_updates"
        case autoUpdate = "auto_update"
        case autoUpdateAllServices = "auto_update_all_services"
    }

    private enum InfoKeys: String, CodingKey {
        case filesOnHost = "files_on_host"
        case deployedContents = "deployed_contents"
        case remoteContents = "remote_contents"
        case deployedServices = "deployed_services"
        case latestServices = "latest_services"
    }
}

extension StackDetail: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let oidContainer = try? container.nestedContainer(keyedBy: OIDKeys.self, forKey: .oid),
           let oid = try? oidContainer.decodeIfPresent(String.self, forKey: .oid) {
            self.id = oid
        } else {
            self.id = try container.decodeIfPresent(String.self, forKey: .oid) ?? ""
        }

        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""

        if let config = try? container.nestedContainer(keyedBy: ConfigKeys.self, forKey: .config) {
            self.serverID = try config.decodeIfPresent(String.self, forKey: .serverID) ?? ""
            self.updatePolicy = StackUpdatePolicy(
                pollForUpdates: try config.decodeIfPresent(Bool.self, forKey: .pollForUpdates) ?? false,
                autoUpdate: try config.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? false,
                autoUpdateAllServices: try config.decodeIfPresent(Bool.self, forKey: .autoUpdateAllServices) ?? false
            )
        } else {
            self.serverID = ""
            self.updatePolicy = .disabled
        }

        let info = try container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
        self.filesOnHost = try info.decodeIfPresent(Bool.self, forKey: .filesOnHost) ?? false

        let deployedContents = try info.decodeIfPresent([StackFileContent].self, forKey: .deployedContents) ?? []
        if deployedContents.isEmpty {
            self.files = try info.decodeIfPresent([StackFileContent].self, forKey: .remoteContents) ?? []
        } else {
            self.files = deployedContents
        }

        self.deployedServices = Self.decodeServiceNames(from: info, key: .deployedServices)
        self.latestServices = Self.decodeServiceNames(from: info, key: .latestServices)
    }

    nonisolated private static func decodeServiceNames(
        from info: KeyedDecodingContainer<InfoKeys>,
        key: InfoKeys
    ) -> [String] {
        struct ServiceSummary: Decodable {
            let serviceName: String?
            private enum CodingKeys: String, CodingKey {
                case serviceName = "service_name"
            }
        }
        let summaries = (try? info.decodeIfPresent([ServiceSummary].self, forKey: key)) ?? nil
        return (summaries ?? []).compactMap(\.serviceName)
    }
}

/// A single compose file's path and contents, from `GetStack.info.deployed_contents`
/// (falling back to `remote_contents`).
nonisolated struct StackFileContent: Sendable, Identifiable, Hashable {
    let path: String
    let contents: String

    var id: String { path }
}

extension StackFileContent: Decodable {}
