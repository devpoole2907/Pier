import Foundation
import Security

/// Thin wrapper around the iOS Keychain for storing per-host Komodo credentials.
enum KeychainService {
    nonisolated private static let apiKeyService = "com.poole.james.pier.komodo.apikey"
    nonisolated private static let apiSecretService = "com.poole.james.pier.komodo.apisecret"

    /// Stores an API key. Replaces any existing entry for the same account.
    nonisolated static func store(apiKey: String, for hostID: UUID) throws {
        try KeychainStore.store(
            value: apiKey,
            service: apiKeyService,
            account: hostID.uuidString,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    /// Retrieves an API key, or returns nil if none is stored.
    nonisolated static func apiKey(for hostID: UUID) throws -> String? {
        try KeychainStore.value(service: apiKeyService, account: hostID.uuidString)
    }

    /// Stores an API secret. Replaces any existing entry for the same account.
    nonisolated static func store(apiSecret: String, for hostID: UUID) throws {
        try KeychainStore.store(
            value: apiSecret,
            service: apiSecretService,
            account: hostID.uuidString,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    /// Retrieves an API secret, or returns nil if none is stored.
    nonisolated static func apiSecret(for hostID: UUID) throws -> String? {
        try KeychainStore.value(service: apiSecretService, account: hostID.uuidString)
    }

    /// Deletes the stored credentials for a host. Safe to call when nothing is stored.
    nonisolated static func delete(for hostID: UUID) throws {
        var keyError: Error?
        var secretError: Error?

        do {
            try KeychainStore.delete(service: apiKeyService, account: hostID.uuidString)
        } catch {
            keyError = error
        }

        do {
            try KeychainStore.delete(service: apiSecretService, account: hostID.uuidString)
        } catch {
            secretError = error
        }

        // Throw the first error encountered, if any
        if let error = keyError ?? secretError {
            throw error
        }
    }
}

enum KeychainStore {
    nonisolated static func store(value: String, service: String, account: String, accessibility: CFString) throws {
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
            kSecAttrAccessible as String: accessibility
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    nonisolated static func value(service: String, account: String) throws -> String? {
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

    nonisolated static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

// MARK: - NPM credentials

extension KeychainService {
    nonisolated private static let npmTokenService = "com.poole.james.pier.npm.jwt"
    nonisolated private static let npmPasswordService = "com.poole.james.pier.npm.password"
    /// Kept only so deleting a host also removes credentials saved by older Pier builds.
    nonisolated private static let npmLegacyAPITokenService = "com.poole.james.pier.npm.apitoken"

    nonisolated static func storeNPMJWT(token: String, for hostID: UUID) throws {
        try KeychainStore.store(
            value: token,
            service: npmTokenService,
            account: hostID.uuidString,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    nonisolated static func npmJWT(for hostID: UUID) throws -> String? {
        try KeychainStore.value(service: npmTokenService, account: hostID.uuidString)
    }

    nonisolated static func storeNPMPassword(password: String, for hostID: UUID) throws {
        try KeychainStore.store(
            value: password,
            service: npmPasswordService,
            account: hostID.uuidString,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    nonisolated static func npmPassword(for hostID: UUID) throws -> String? {
        try KeychainStore.value(service: npmPasswordService, account: hostID.uuidString)
    }

    nonisolated static func deleteNPMCredentials(for hostID: UUID) throws {
        var errors: [Error] = []
        for svc in [npmTokenService, npmPasswordService, npmLegacyAPITokenService] {
            do {
                try KeychainStore.delete(service: svc, account: hostID.uuidString)
            } catch {
                errors.append(error)
            }
        }
        if let first = errors.first {
            throw first
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
