@preconcurrency import Foundation

struct NPMProxyHost: Sendable, Decodable, Identifiable {
    let id: Int
    let domain_names: [String]
    let forward_scheme: String?
    let forward_host: String
    let forward_port: Int
    let certificate_id: Int?
    let ssl_forced: FlexibleBool?
    let hsts_enabled: FlexibleBool?
    let hsts_subdomains: FlexibleBool?
    let http2_support: FlexibleBool?
    let allow_websocket_upgrade: FlexibleBool?
    let block_exploits: FlexibleBool?
    let caching_enabled: FlexibleBool?
    let access_list_id: Int?
    let advanced_config: String?
    let enabled: FlexibleBool?
    let locations: [NPMLocation]?
    let trust_forwarded_proto: FlexibleBool?

    // Inlined expanded objects (when ?expand=certificate,access_list,owner is used)
    let certificate: NPMCertificate?
    let access_list: NPMAccessList?
    let owner: NPMUser?
}

struct NPMProxyHostCreate: Sendable, Encodable {
    let domain_names: [String]
    let forward_scheme: String
    let forward_host: String
    let forward_port: Int
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let allow_websocket_upgrade: FlexibleBool
    let block_exploits: FlexibleBool
    let caching_enabled: FlexibleBool
    let access_list_id: Int?
    let advanced_config: String
    let locations: [NPMLocationCreate]
    // Optional + omitted when nil: added in NPM v2.15, so sending it to older
    // servers triggers a 400 "must NOT have additional properties".
    let trust_forwarded_proto: FlexibleBool?

    init(
        domainNames: [String],
        forwardScheme: String = "http",
        forwardHost: String,
        forwardPort: Int,
        certificateID: Int? = nil,
        sslForced: Bool = false,
        hstsEnabled: Bool = false,
        hstsSubdomains: Bool = false,
        http2Support: Bool = false,
        allowWebsocketUpgrade: Bool = false,
        blockExploits: Bool = true,
        cachingEnabled: Bool = false,
        accessListID: Int? = nil,
        advancedConfig: String = "",
        locations: [NPMLocationCreate] = [],
        trustForwardedProto: Bool? = nil
    ) {
        self.domain_names = domainNames
        self.forward_scheme = forwardScheme
        self.forward_host = forwardHost
        self.forward_port = forwardPort
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.allow_websocket_upgrade = FlexibleBool(value: allowWebsocketUpgrade)
        self.block_exploits = FlexibleBool(value: blockExploits)
        self.caching_enabled = FlexibleBool(value: cachingEnabled)
        self.access_list_id = accessListID
        self.advanced_config = advancedConfig
        self.locations = locations
        self.trust_forwarded_proto = trustForwardedProto.map { FlexibleBool(value: $0) }
    }
}

struct NPMProxyHostUpdate: Sendable, Encodable {
    let domain_names: [String]
    let forward_scheme: String
    let forward_host: String
    let forward_port: Int
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let allow_websocket_upgrade: FlexibleBool
    let block_exploits: FlexibleBool
    let caching_enabled: FlexibleBool
    let access_list_id: Int?
    let advanced_config: String
    let locations: [NPMLocationCreate]
    let enabled: FlexibleBool
    // Optional + omitted when nil: added in NPM v2.15, unsupported on older servers.
    let trust_forwarded_proto: FlexibleBool?

    init(
        domainNames: [String],
        forwardScheme: String,
        forwardHost: String,
        forwardPort: Int,
        certificateID: Int?,
        sslForced: Bool,
        hstsEnabled: Bool,
        hstsSubdomains: Bool,
        http2Support: Bool,
        allowWebsocketUpgrade: Bool,
        blockExploits: Bool,
        cachingEnabled: Bool,
        accessListID: Int?,
        advancedConfig: String,
        locations: [NPMLocationCreate],
        enabled: Bool,
        trustForwardedProto: Bool? = nil
    ) {
        self.domain_names = domainNames
        self.forward_scheme = forwardScheme
        self.forward_host = forwardHost
        self.forward_port = forwardPort
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.allow_websocket_upgrade = FlexibleBool(value: allowWebsocketUpgrade)
        self.block_exploits = FlexibleBool(value: blockExploits)
        self.caching_enabled = FlexibleBool(value: cachingEnabled)
        self.access_list_id = accessListID
        self.advanced_config = advancedConfig
        self.locations = locations
        self.enabled = FlexibleBool(value: enabled)
        self.trust_forwarded_proto = trustForwardedProto.map { FlexibleBool(value: $0) }
    }

    init(from proxy: NPMProxyHost) {
        self.domain_names = proxy.domain_names
        self.forward_scheme = proxy.forward_scheme ?? "http"
        self.forward_host = proxy.forward_host
        self.forward_port = proxy.forward_port
        self.certificate_id = proxy.certificate_id
        self.ssl_forced = proxy.ssl_forced ?? FlexibleBool(value: false)
        self.hsts_enabled = proxy.hsts_enabled ?? FlexibleBool(value: false)
        self.hsts_subdomains = proxy.hsts_subdomains ?? FlexibleBool(value: false)
        self.http2_support = proxy.http2_support ?? FlexibleBool(value: false)
        self.allow_websocket_upgrade = proxy.allow_websocket_upgrade ?? FlexibleBool(value: false)
        self.block_exploits = proxy.block_exploits ?? FlexibleBool(value: true)
        self.caching_enabled = proxy.caching_enabled ?? FlexibleBool(value: false)
        self.access_list_id = proxy.access_list_id
        self.advanced_config = proxy.advanced_config ?? ""
        self.locations = proxy.locations?.map {
            NPMLocationCreate(
                path: $0.path,
                forwardScheme: $0.forward_scheme ?? "http",
                forwardHost: $0.forward_host,
                forwardPort: $0.forward_port,
                advancedConfig: $0.advanced_config ?? ""
            )
        } ?? []
        self.enabled = proxy.enabled ?? FlexibleBool(value: true)
        // Preserve whatever the server returned (nil on < v2.15 → omitted on write-back).
        self.trust_forwarded_proto = proxy.trust_forwarded_proto
    }
}
