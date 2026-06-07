@preconcurrency import Foundation

struct NPMCertificate: Sendable, Decodable, Identifiable {
    let id: Int
    let provider: String?
    let nice_name: String
    let domain_names: [String]
    let expires_on: String?
    let meta: NPMCertificateMeta?
    let owner: NPMUser?
}

struct NPMCertificateMeta: Sendable, Decodable {
    let letsencrypt_email: String?
    let dns_challenge: FlexibleBool?
    let dns_provider: String?
    let propagation_seconds: Int?
}

extension NPMCertificate {
    /// Parses NPM's `expires_on` (ISO8601, or MySQL `yyyy-MM-dd HH:mm:ss`) into a `Date`.
    var expiryDate: Date? {
        guard let expires_on else { return nil }
        if let iso = try? Date(expires_on, strategy: .iso8601) { return iso }
        return NPMCertificate.mysqlDateFormatter.date(from: expires_on)
    }

    /// True once the certificate's validity window has passed.
    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }

    /// True when the certificate is still valid but expires within 14 days.
    var isExpiringSoon: Bool {
        guard let expiryDate, !isExpired else { return false }
        return expiryDate < Date().addingTimeInterval(14 * 24 * 60 * 60)
    }

    private static let mysqlDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

/// Create payload for a Let's Encrypt certificate. Supports both the HTTP-01
/// challenge (domains must be reachable on :80) and the DNS-01 challenge (required
/// for wildcards / non-public hosts), which additionally needs a certbot DNS
/// provider key, that provider's credentials blob, and an optional propagation wait.
/// Custom-certificate uploads remain out of scope (multipart, handled in NPM's UI).
struct NPMCertificateCreate: Sendable, Encodable {
    let provider: String
    let domain_names: [String]
    let meta: Meta

    struct Meta: Sendable, Encodable {
        let letsencrypt_email: String
        let letsencrypt_agree: FlexibleBool
        let dns_challenge: FlexibleBool
        // Only sent for the DNS-01 challenge; omitted (nil) for HTTP-01.
        let dns_provider: String?
        let dns_provider_credentials: String?
        let propagation_seconds: Int?
    }

    /// HTTP-01 challenge.
    init(domainNames: [String], letsencryptEmail: String) {
        self.provider = "letsencrypt"
        self.domain_names = domainNames
        self.meta = Meta(
            letsencrypt_email: letsencryptEmail,
            letsencrypt_agree: FlexibleBool(value: true),
            dns_challenge: FlexibleBool(value: false),
            dns_provider: nil,
            dns_provider_credentials: nil,
            propagation_seconds: nil
        )
    }

    /// DNS-01 challenge.
    init(
        domainNames: [String],
        letsencryptEmail: String,
        dnsProvider: String,
        dnsProviderCredentials: String,
        propagationSeconds: Int?
    ) {
        self.provider = "letsencrypt"
        self.domain_names = domainNames
        self.meta = Meta(
            letsencrypt_email: letsencryptEmail,
            letsencrypt_agree: FlexibleBool(value: true),
            dns_challenge: FlexibleBool(value: true),
            dns_provider: dnsProvider,
            dns_provider_credentials: dnsProviderCredentials,
            propagation_seconds: propagationSeconds
        )
    }
}
