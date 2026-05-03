import Foundation
import SwiftData

/// A saved Portainer host. The JWT itself lives in the Keychain, keyed by `id`.
@Model
final class Host {
    /// Stable identifier used as the Keychain account key for the JWT.
    var id: UUID = UUID()

    /// Friendly display name shown in lists, e.g. "Home Server".
    var name: String = ""

    /// Base URL of the Portainer instance, e.g. https://10.0.0.5:9443
    var baseURL: String = ""

    /// Username for authentication. The password is never persisted; we obtain a JWT once and cache it in the Keychain.
    var username: String = ""

    /// Whether HTTPS certificate validation should be skipped. Some self-signed local Portainer installs need this.
    var allowsInsecureTLS: Bool = false

    /// Date this host was added.
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        username: String,
        allowsInsecureTLS: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.username = username
        self.allowsInsecureTLS = allowsInsecureTLS
        self.createdAt = createdAt
    }
}
