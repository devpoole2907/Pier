@preconcurrency import Foundation

struct NPMDeadHost: Sendable, Decodable, Identifiable {
    let id: Int
    let domain_names: [String]
    let certificate_id: Int?
    let ssl_forced: FlexibleBool?
    let hsts_enabled: FlexibleBool?
    let hsts_subdomains: FlexibleBool?
    let http2_support: FlexibleBool?
    let advanced_config: String?
    let enabled: FlexibleBool?
    let owner: NPMUser?
}

struct NPMDeadHostCreate: Sendable, Encodable {
    let domain_names: [String]
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let advanced_config: String

    init(
        domainNames: [String],
        certificateID: Int? = nil,
        sslForced: Bool = false,
        hstsEnabled: Bool = false,
        hstsSubdomains: Bool = false,
        http2Support: Bool = false,
        advancedConfig: String = ""
    ) {
        self.domain_names = domainNames
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.advanced_config = advancedConfig
    }
}

struct NPMDeadHostUpdate: Sendable, Encodable {
    let domain_names: [String]
    let certificate_id: Int?
    let ssl_forced: FlexibleBool
    let hsts_enabled: FlexibleBool
    let hsts_subdomains: FlexibleBool
    let http2_support: FlexibleBool
    let advanced_config: String
    let enabled: FlexibleBool

    init(
        domainNames: [String],
        certificateID: Int?,
        sslForced: Bool,
        hstsEnabled: Bool,
        hstsSubdomains: Bool,
        http2Support: Bool,
        advancedConfig: String,
        enabled: Bool
    ) {
        self.domain_names = domainNames
        self.certificate_id = certificateID
        self.ssl_forced = FlexibleBool(value: sslForced)
        self.hsts_enabled = FlexibleBool(value: hstsEnabled)
        self.hsts_subdomains = FlexibleBool(value: hstsSubdomains)
        self.http2_support = FlexibleBool(value: http2Support)
        self.advanced_config = advancedConfig
        self.enabled = FlexibleBool(value: enabled)
    }

    init(from host: NPMDeadHost) {
        self.domain_names = host.domain_names
        self.certificate_id = host.certificate_id
        self.ssl_forced = host.ssl_forced ?? FlexibleBool(value: false)
        self.hsts_enabled = host.hsts_enabled ?? FlexibleBool(value: false)
        self.hsts_subdomains = host.hsts_subdomains ?? FlexibleBool(value: false)
        self.http2_support = host.http2_support ?? FlexibleBool(value: false)
        self.advanced_config = host.advanced_config ?? ""
        self.enabled = host.enabled ?? FlexibleBool(value: true)
    }
}
