@preconcurrency import Foundation

struct NPMAccessListItem: Sendable, Decodable, Encodable, Identifiable {
    let serverID: Int?
    let username: String
    let password: String
    var localID: UUID = UUID()

    var id: UUID { localID }

    enum CodingKeys: String, CodingKey {
        case serverID = "id"
        case username
        case password
    }

    init(id: Int? = nil, username: String, password: String) {
        self.serverID = id
        self.username = username
        self.password = password
        self.localID = UUID()
    }
}

struct NPMAccessListClient: Sendable, Decodable, Encodable, Identifiable {
    let serverID: Int?
    let address: String
    let directive: String
    var localID: UUID = UUID()

    var id: UUID { localID }

    enum CodingKeys: String, CodingKey {
        case serverID = "id"
        case address
        case directive
    }

    init(id: Int? = nil, address: String, directive: String) {
        self.serverID = id
        self.address = address
        self.directive = directive
        self.localID = UUID()
    }
}

struct NPMAccessList: Sendable, Decodable, Identifiable {
    let id: Int
    let name: String
    let satisfy_any: FlexibleBool?
    let pass_auth: FlexibleBool?
    let proxy_host_count: Int?
    let items: [NPMAccessListItem]?
    let clients: [NPMAccessListClient]?
    let owner: NPMUser?
}

struct NPMAccessListCreate: Sendable, Encodable {
    let name: String
    let satisfy_any: FlexibleBool
    let pass_auth: FlexibleBool
    let items: [NPMAccessListItem]
    let clients: [NPMAccessListClient]

    init(
        name: String,
        satisfyAny: Bool = false,
        passAuth: Bool = false,
        items: [NPMAccessListItem] = [],
        clients: [NPMAccessListClient] = []
    ) {
        self.name = name
        self.satisfy_any = FlexibleBool(value: satisfyAny)
        self.pass_auth = FlexibleBool(value: passAuth)
        self.items = items
        self.clients = clients
    }
}

struct NPMAccessListUpdate: Sendable, Encodable {
    let name: String
    let satisfy_any: FlexibleBool
    let pass_auth: FlexibleBool
    let items: [NPMAccessListItem]
    let clients: [NPMAccessListClient]

    init(
        name: String,
        satisfyAny: Bool,
        passAuth: Bool,
        items: [NPMAccessListItem],
        clients: [NPMAccessListClient]
    ) {
        self.name = name
        self.satisfy_any = FlexibleBool(value: satisfyAny)
        self.pass_auth = FlexibleBool(value: passAuth)
        self.items = items
        self.clients = clients
    }

    init(from list: NPMAccessList) {
        self.name = list.name
        self.satisfy_any = list.satisfy_any ?? FlexibleBool(value: false)
        self.pass_auth = list.pass_auth ?? FlexibleBool(value: false)
        self.items = list.items ?? []
        self.clients = list.clients ?? []
    }
}
