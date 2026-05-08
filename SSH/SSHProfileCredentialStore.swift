import Foundation
import OSLog

struct SSHProfileCredentialStore {
    private static let logger = Logger(subsystem: "com.poole.james.pier", category: "SSHProfileCredentialStore")

    /// Persists only the credentials relevant to the current auth method and clears any that no longer apply.
    func writeCredentials(
        for profile: SSHProfile,
        authType: SSHAuthType,
        password: String,
        privateKeyPEM: String,
        keyPassphrase: String
    ) async throws {
        switch authType {
        case .password:
            if password.isEmpty {
                try await KeychainHelper.shared.delete(key: profile.passwordKey)
            } else {
                try await KeychainHelper.shared.save(key: profile.passwordKey, value: password)
            }
            try await KeychainHelper.shared.delete(key: profile.privateKeyKey)
            try await KeychainHelper.shared.delete(key: profile.passphraseKey)

        case .privateKey:
            if privateKeyPEM.isEmpty {
                try await KeychainHelper.shared.delete(key: profile.privateKeyKey)
            } else {
                try await KeychainHelper.shared.save(key: profile.privateKeyKey, value: privateKeyPEM)
            }

            if keyPassphrase.isEmpty {
                try await KeychainHelper.shared.delete(key: profile.passphraseKey)
            } else {
                try await KeychainHelper.shared.save(key: profile.passphraseKey, value: keyPassphrase)
            }
            try await KeychainHelper.shared.delete(key: profile.passwordKey)
        }
    }

    func snapshotCredentials(for profile: SSHProfile) async throws -> SSHCredentialSnapshot {
        let helper = KeychainHelper.shared
        let passwordValue = try await helper.read(key: profile.passwordKey)
        let privateKeyValue = try await helper.read(key: profile.privateKeyKey)
        let passphraseValue = try await helper.read(key: profile.passphraseKey)
        return SSHCredentialSnapshot(
            password: passwordValue,
            privateKey: privateKeyValue,
            passphrase: passphraseValue
        )
    }

    func restoreCredentials(_ snapshot: SSHCredentialSnapshot, for profile: SSHProfile) async throws {
        let helper = KeychainHelper.shared
        if let password = snapshot.password {
            try await helper.save(key: profile.passwordKey, value: password)
        } else {
            try await helper.delete(key: profile.passwordKey)
        }

        if let privateKey = snapshot.privateKey {
            try await helper.save(key: profile.privateKeyKey, value: privateKey)
        } else {
            try await helper.delete(key: profile.privateKeyKey)
        }

        if let passphrase = snapshot.passphrase {
            try await helper.save(key: profile.passphraseKey, value: passphrase)
        } else {
            try await helper.delete(key: profile.passphraseKey)
        }
    }

    func clearCredentials(for profile: SSHProfile) async throws {
        try await deleteCredential(forKey: profile.passwordKey, label: "password")
        try await deleteCredential(forKey: profile.privateKeyKey, label: "private key")
        try await deleteCredential(forKey: profile.passphraseKey, label: "passphrase")
    }

    private func deleteCredential(forKey key: String, label: String) async throws {
        do {
            try await KeychainHelper.shared.delete(key: key)
        } catch let error as KeychainError where isIgnorableDeleteError(error) {
            return
        } catch {
            Self.logger.error("Failed to delete SSH \(label, privacy: .public) from Keychain: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func isIgnorableDeleteError(_ error: KeychainError) -> Bool {
        switch error {
        case .unhandledStatus(let status):
            status == errSecItemNotFound
        default:
            false
        }
    }
}

struct SSHCredentialSnapshot: Sendable {
    let password: String?
    let privateKey: String?
    let passphrase: String?
}
