import Foundation
import SwiftData

/// A saved Komodo Core connection. Credentials (API key + secret) live in the Keychain, keyed by `id`.
@Model
final class Host {
    /// Stable identifier used as the Keychain account key for the API key/secret.
    var id: UUID = UUID()

    /// Friendly display name shown in lists, e.g. "Home Server".
    var name: String = ""

    /// Base URL of the Komodo Core instance, e.g. http://10.0.0.5:9120
    var baseURL: String = ""

    /// Whether HTTPS certificate validation should be skipped. Some self-signed local Komodo installs need this.
    var allowsInsecureTLS: Bool = false

    /// Date this host was added.
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        allowsInsecureTLS: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.allowsInsecureTLS = allowsInsecureTLS
        self.createdAt = createdAt
    }
}
