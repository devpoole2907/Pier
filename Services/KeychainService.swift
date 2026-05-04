import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing per-host Portainer credentials.
enum KeychainService {
    nonisolated private static let tokenService = "com.poole.james.pier.jwt"
    nonisolated private static let passwordService = "com.poole.james.pier.password"

    /// Stores a token. Replaces any existing entry for the same account.
    nonisolated static func store(token: String, for hostID: UUID) throws {
        try store(value: token, service: tokenService, for: hostID)
    }

    /// Retrieves a token, or returns nil if none is stored.
    nonisolated static func token(for hostID: UUID) throws -> String? {
        try value(for: hostID, service: tokenService)
    }

    /// Stores the Portainer password for silent re-auth after app relaunch.
    nonisolated static func store(password: String, for hostID: UUID) throws {
        try store(value: password, service: passwordService, for: hostID)
    }

    /// Retrieves a password, or returns nil if none is stored.
    nonisolated static func password(for hostID: UUID) throws -> String? {
        try value(for: hostID, service: passwordService)
    }

    /// Deletes the stored credentials for a host. Safe to call when nothing is stored.
    nonisolated static func delete(for hostID: UUID) throws {
        try deleteValue(for: hostID, service: tokenService)
        try deleteValue(for: hostID, service: passwordService)
    }

    private nonisolated static func store(value: String, service: String, for hostID: UUID) throws {
        let account = hostID.uuidString
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private nonisolated static func value(for hostID: UUID, service: String) throws -> String? {
        let account = hostID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    private nonisolated static func deleteValue(for hostID: UUID, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: hostID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Could not encode the token for the keychain."
        case .unhandledStatus(let status):
            "Keychain error \(status)."
        }
    }
}
