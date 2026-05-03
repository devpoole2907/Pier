import Foundation

/// A Portainer-managed compose stack as returned by `GET /stacks`.
struct Stack: Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let type: Int
    let endpointID: Int
    let status: Int
    let creationDate: Date?
    let updateDate: Date?
    let projectPath: String?

    /// Stack status: 1 = active, 2 = inactive (per Portainer convention).
    var isActive: Bool { status == 1 }

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case endpointID = "EndpointId"
        case status = "Status"
        case creationDate = "CreationDate"
        case updateDate = "UpdateDate"
        case projectPath = "ProjectPath"
    }

}

extension Stack: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decodeIfPresent(Int.self, forKey: .type) ?? 0
        self.endpointID = try container.decodeIfPresent(Int.self, forKey: .endpointID) ?? 0
        self.status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
        self.projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)

        if let creation = try container.decodeIfPresent(TimeInterval.self, forKey: .creationDate), creation > 0 {
            self.creationDate = Date(timeIntervalSince1970: creation)
        } else {
            self.creationDate = nil
        }
        if let update = try container.decodeIfPresent(TimeInterval.self, forKey: .updateDate), update > 0 {
            self.updateDate = Date(timeIntervalSince1970: update)
        } else {
            self.updateDate = nil
        }
    }
}

/// Stack file content - returned from `GET /stacks/{id}/file` as `{ "StackFileContent": "..." }`.
struct StackFile: Sendable {
    let stackFileContent: String

    private enum CodingKeys: String, CodingKey {
        case stackFileContent = "StackFileContent"
    }
}

extension StackFile: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.stackFileContent = try container.decode(String.self, forKey: .stackFileContent)
    }
}
