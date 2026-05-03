import Foundation

/// Full container inspection as returned by `GET /containers/{id}/json`.
/// Only the fields actually shown in the detail view are decoded; everything else is ignored.
struct ContainerDetail: Identifiable, Sendable {
    let id: String
    let name: String
    let created: Date
    let path: String
    let args: [String]
    let state: State
    let image: String
    let restartCount: Int
    let mounts: [Mount]
    let config: Config
    let networkSettings: NetworkSettings

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case created = "Created"
        case path = "Path"
        case args = "Args"
        case state = "State"
        case image = "Image"
        case restartCount = "RestartCount"
        case mounts = "Mounts"
        case config = "Config"
        case networkSettings = "NetworkSettings"
    }

}

extension ContainerDetail: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        let createdString = try container.decode(String.self, forKey: .created)
        self.created = (try? Date(createdString, strategy: .iso8601)) ?? .now
        self.path = try container.decode(String.self, forKey: .path)
        self.args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        self.state = try container.decode(State.self, forKey: .state)
        self.image = try container.decode(String.self, forKey: .image)
        self.restartCount = try container.decodeIfPresent(Int.self, forKey: .restartCount) ?? 0
        self.mounts = try container.decodeIfPresent([Mount].self, forKey: .mounts) ?? []
        self.config = try container.decode(Config.self, forKey: .config)
        self.networkSettings = try container.decode(NetworkSettings.self, forKey: .networkSettings)
    }

    struct State: Sendable {
        let status: String
        let running: Bool
        let pid: Int
        let exitCode: Int
        let startedAt: Date?
        let finishedAt: Date?

        private enum CodingKeys: String, CodingKey {
            case status = "Status"
            case running = "Running"
            case pid = "Pid"
            case exitCode = "ExitCode"
            case startedAt = "StartedAt"
            case finishedAt = "FinishedAt"
        }

    }

    struct Mount: Sendable, Identifiable, Hashable {
        let type: String
        let source: String
        let destination: String
        let mode: String
        let readWrite: Bool

        var id: String { "\(source)->\(destination)" }

        private enum CodingKeys: String, CodingKey {
            case type = "Type"
            case source = "Source"
            case destination = "Destination"
            case mode = "Mode"
            case readWrite = "RW"
        }
    }

    struct Config: Sendable {
        let env: [String]
        let labels: [String: String]
        let image: String
        let workingDir: String
        let entrypoint: [String]?
        let cmd: [String]?

        private enum CodingKeys: String, CodingKey {
            case env = "Env"
            case labels = "Labels"
            case image = "Image"
            case workingDir = "WorkingDir"
            case entrypoint = "Entrypoint"
            case cmd = "Cmd"
        }
    }

    struct NetworkSettings: Sendable {
        let networks: [String: NetworkInfo]

        private enum CodingKeys: String, CodingKey {
            case networks = "Networks"
        }
    }

    struct NetworkInfo: Sendable, Hashable {
        let ipAddress: String
        let gateway: String
        let macAddress: String

        private enum CodingKeys: String, CodingKey {
            case ipAddress = "IPAddress"
            case gateway = "Gateway"
            case macAddress = "MacAddress"
        }
    }
}

extension ContainerDetail.State: Decodable {
    nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.status = try container.decode(String.self, forKey: .status)
            self.running = try container.decode(Bool.self, forKey: .running)
            self.pid = try container.decodeIfPresent(Int.self, forKey: .pid) ?? 0
            self.exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode) ?? 0

            if let startedRaw = try container.decodeIfPresent(String.self, forKey: .startedAt),
               let date = try? Date(startedRaw, strategy: .iso8601) {
                self.startedAt = date
            } else {
                self.startedAt = nil
            }
            if let finishedRaw = try container.decodeIfPresent(String.self, forKey: .finishedAt),
               let date = try? Date(finishedRaw, strategy: .iso8601) {
                self.finishedAt = date
            } else {
                self.finishedAt = nil
            }
        }
}

extension ContainerDetail.Mount: Decodable {}

extension ContainerDetail.Config: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.env = try container.decodeIfPresent([String].self, forKey: .env) ?? []
        self.labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        self.image = try container.decode(String.self, forKey: .image)
        self.workingDir = try container.decodeIfPresent(String.self, forKey: .workingDir) ?? ""
        self.entrypoint = try container.decodeIfPresent([String].self, forKey: .entrypoint)
        self.cmd = try container.decodeIfPresent([String].self, forKey: .cmd)
    }
}

extension ContainerDetail.NetworkSettings: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.networks = try container.decodeIfPresent([String: ContainerDetail.NetworkInfo].self, forKey: .networks) ?? [:]
    }
}

extension ContainerDetail.NetworkInfo: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress) ?? ""
        self.gateway = try container.decodeIfPresent(String.self, forKey: .gateway) ?? ""
        self.macAddress = try container.decodeIfPresent(String.self, forKey: .macAddress) ?? ""
    }
}

/// Environment variable parsed from the `KEY=VALUE` strings the Docker API returns.
struct EnvVar: Sendable, Identifiable, Hashable {
    let key: String
    let value: String

    var id: String { key }

    init?(rawString: String) {
        guard let separatorIndex = rawString.firstIndex(of: "=") else { return nil }
        self.key = String(rawString[..<separatorIndex])
        self.value = String(rawString[rawString.index(after: separatorIndex)...])
    }
}
