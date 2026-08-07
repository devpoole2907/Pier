import Foundation
import SwiftData

/// A saved Nginx Proxy Manager host. Credentials live in the Keychain, keyed by `id`.
@Model
final class NPMHost {
    var id: UUID = UUID()
    var name: String = ""
    /// Base URL of the NPM instance, e.g. http://10.0.0.5:81
    var baseURL: String = ""
    /// Retained for compatibility with stores created when Pier offered an unsupported API-token
    /// mode. All hosts now use NPM's email/password JWT exchange.
    var authMethodRaw: String = "password"
    /// Email/username used to request an NPM bearer token.
    var identity: String = ""
    var allowsInsecureTLS: Bool = false
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        identity: String = "",
        allowsInsecureTLS: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authMethodRaw = "password"
        self.identity = identity
        self.allowsInsecureTLS = allowsInsecureTLS
        self.createdAt = createdAt
    }
}
