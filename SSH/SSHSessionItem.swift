import SwiftData
import SwiftUI

/// Encapsulates a single SSH session: one profile, one connection, one terminal bridge.
@MainActor
@Observable
final class SSHSessionItem: Identifiable {
    let id = UUID()
    let profile: SSHProfile
    let connection: SSHConnection
    let bridge: SSHTerminalBridge
    var titleOverride: String?
    var wantsKeyboard = false
    var pendingFingerprint: String?
    private var fingerprintContinuation: CheckedContinuation<Bool, Never>?

    var sessionTitle: String { titleOverride ?? profile.displayName }
    var sessionSubtitle: String { "\(profile.username)@\(profile.hostDisplay)" }

    var statusText: String {
        switch connection.state {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        case .failed: "Failed"
        }
    }

    var statusColor: Color {
        switch connection.state {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .secondary
        case .failed: .red
        }
    }

    init(profile: SSHProfile) {
        self.profile = profile
        self.connection = SSHConnection()
        self.bridge = SSHTerminalBridge()

        bridge.sendToSSH = { [connection] data in connection.send(data) }
        bridge.onResize = { [connection] cols, rows in connection.resize(cols: cols, rows: rows) }
        bridge.onTitleChange = { [weak self] title in
            guard !title.isEmpty else { return }
            self?.titleOverride = title
        }
        bridge.onKeyboardVisibilityChange = { [weak self] isVisible in
            self?.wantsKeyboard = isVisible
        }
        connection.onOutput = { [bridge] bytes in bridge.receive(bytes: bytes) }
    }

    func connectIfNeeded(modelContext: ModelContext) async {
        switch connection.state {
        case .connected:
            wantsKeyboard = true
            return
        case .connecting:
            return
        case .disconnected, .failed:
            break
        }
        await connect(modelContext: modelContext)
    }

    func reconnect(modelContext: ModelContext) async {
        confirmFingerprint(accepted: false)
        await connection.disconnect()
        titleOverride = nil
        wantsKeyboard = false
        await connect(modelContext: modelContext)
    }

    func disconnect() async {
        confirmFingerprint(accepted: false)
        bridge.hideKeyboard()
        await connection.disconnect()
        titleOverride = nil
        wantsKeyboard = false
    }

    func focusSession() { wantsKeyboard = true }

    func hideKeyboard() {
        wantsKeyboard = false
        bridge.hideKeyboard()
    }

    func presentFingerprintConfirmation(_ fingerprint: String) async -> Bool {
        if fingerprintContinuation != nil { confirmFingerprint(accepted: false) }
        pendingFingerprint = fingerprint
        return await withCheckedContinuation { continuation in
            self.fingerprintContinuation = continuation
        }
    }

    func confirmFingerprint(accepted: Bool) {
        fingerprintContinuation?.resume(returning: accepted)
        fingerprintContinuation = nil
        pendingFingerprint = nil
    }

    private func connect(modelContext: ModelContext) async {
        titleOverride = nil
        wantsKeyboard = false

        connection.onNewFingerprint = { [weak self] fingerprint in
            guard let self else { return false }
            let accepted = await self.presentFingerprintConfirmation(fingerprint)
            if accepted {
                let previous = self.profile.knownHostFingerprint
                self.profile.knownHostFingerprint = fingerprint
                do {
                    try modelContext.save()
                } catch {
                    self.profile.knownHostFingerprint = previous
                    return false
                }
            }
            return accepted
        }

        do {
            let auth = try await resolveAuth(for: profile)
            try await connection.connect(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                auth: auth,
                knownFingerprint: profile.knownHostFingerprint
            )
            wantsKeyboard = true
        } catch {
            connection.markFailed(error.localizedDescription)
        }
    }

    private func resolveAuth(for profile: SSHProfile) async throws -> SSHAuth {
        switch profile.authType {
        case .password:
            guard let password = try await KeychainHelper.shared.read(key: profile.passwordKey),
                  !password.isEmpty else {
                throw SSHCredentialError.missingPassword
            }
            return .password(password)
        case .privateKey:
            guard let key = try await KeychainHelper.shared.read(key: profile.privateKeyKey),
                  !key.isEmpty else {
                throw SSHCredentialError.missingPrivateKey
            }
            let passphrase = try await KeychainHelper.shared.read(key: profile.passphraseKey)
            return .privateKey(pem: key, passphrase: passphrase)
        }
    }
}
