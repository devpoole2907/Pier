import Foundation
import SwiftData

enum NPMAuthMethod: String, CaseIterable, Identifiable, Sendable {
    case password
    case token

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .password: "Email + Password"
        case .token: "API Token"
        }
    }
}

/// A saved Nginx Proxy Manager host. Credentials live in the Keychain, keyed by `id`.
@Model
final class NPMHost {
    var id: UUID = UUID()
    var name: String = ""
    /// Base URL of the NPM instance, e.g. http://10.0.0.5:81
    var baseURL: String = ""
    /// Raw storage for auth method enum: "password" or "token"
    var authMethodRaw: String = NPMAuthMethod.password.rawValue
    /// Email/username (empty for token auth)
    var identity: String = ""
    var allowsInsecureTLS: Bool = false
    var createdAt: Date = Date.now

    var authMethod: NPMAuthMethod {
        NPMAuthMethod(rawValue: authMethodRaw) ?? .password
    }

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        authMethod: NPMAuthMethod = .password,
        identity: String = "",
        allowsInsecureTLS: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authMethodRaw = authMethod.rawValue
        self.identity = identity
        self.allowsInsecureTLS = allowsInsecureTLS
        self.createdAt = createdAt
    }
}
