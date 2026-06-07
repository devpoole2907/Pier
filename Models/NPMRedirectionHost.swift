@preconcurrency import Foundation

struct NPMRedirectionHost: Sendable, Decodable, Identifiable {
    let id: Int
    let domain_names: [String]
    let forward_http_code: Int
    let forward_scheme: String?
    let forward_domain_name: String
    let preserve_path: FlexibleBool?
    let certificate_id: Int?
    let ssl_forced: FlexibleBool?
    let hsts_enabled: FlexibleBool?
    let hsts_subdomains: FlexibleBool?
    let http2_support: FlexibleBool?
    let block_exploits: FlexibleBool?
    let advanced_config: String?
    let enabled: FlexibleBool?
    let owner: NPMUser?
}

struct NPMRedirectionHostCreate: Sendable, Encodable {
    let domain_names: [String]
    let forward_http_code: Int
    let forward_scheme: String
    let forward_domain_name: String
    let preserve_path: FlexibleBool
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let block_exploits: FlexibleBool
    let advanced_config: String

    init(
        domainNames: [String],
        forwardHTTPCode: Int = 301,
        forwardScheme: String = "auto",
        forwardDomainName: String,
        preservePath: Bool = true,
        certificateID: Int? = nil,
        sslForced: Bool = false,
        hstsEnabled: Bool = false,
        hstsSubdomains: Bool = false,
        http2Support: Bool = false,
        blockExploits: Bool = true,
        advancedConfig: String = ""
    ) {
        self.domain_names = domainNames
        self.forward_http_code = forwardHTTPCode
        self.forward_scheme = forwardScheme
        self.forward_domain_name = forwardDomainName
        self.preserve_path = FlexibleBool(value: preservePath)
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.block_exploits = FlexibleBool(value: blockExploits)
        self.advanced_config = advancedConfig
    }
}

struct NPMRedirectionHostUpdate: Sendable, Encodable {
    let domain_names: [String]
    let forward_http_code: Int
    let forward_scheme: String
    let forward_domain_name: String
    let preserve_path: FlexibleBool
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let block_exploits: FlexibleBool
    let advanced_config: String
    let enabled: FlexibleBool

    init(
        domainNames: [String],
        forwardHTTPCode: Int,
        forwardScheme: String,
        forwardDomainName: String,
        preservePath: Bool,
        certificateID: Int?,
        sslForced: Bool,
        hstsEnabled: Bool,
        hstsSubdomains: Bool,
        http2Support: Bool,
        blockExploits: Bool,
        advancedConfig: String,
        enabled: Bool
    ) {
        self.domain_names = domainNames
        self.forward_http_code = forwardHTTPCode
        self.forward_scheme = forwardScheme
        self.forward_domain_name = forwardDomainName
        self.preserve_path = FlexibleBool(value: preservePath)
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.block_exploits = FlexibleBool(value: blockExploits)
        self.advanced_config = advancedConfig
        self.enabled = FlexibleBool(value: enabled)
    }

    init(from host: NPMRedirectionHost) {
        self.domain_names = host.domain_names
        self.forward_http_code = host.forward_http_code
        self.forward_scheme = host.forward_scheme ?? "auto"
        self.forward_domain_name = host.forward_domain_name
        self.preserve_path = host.preserve_path ?? FlexibleBool(value: true)
        self.certificate_id = host.certificate_id
        self.ssl_forced = host.ssl_forced ?? FlexibleBool(value: false)
        self.hsts_enabled = host.hsts_enabled ?? FlexibleBool(value: false)
        self.hsts_subdomains = host.hsts_subdomains ?? FlexibleBool(value: false)
        self.http2_support = host.http2_support ?? FlexibleBool(value: false)
        self.block_exploits = host.block_exploits ?? FlexibleBool(value: true)
        self.advanced_config = host.advanced_config ?? ""
        self.enabled = host.enabled ?? FlexibleBool(value: true)
    }
}
