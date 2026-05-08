import SwiftUI
import SwiftData

struct SSHProfileEditSheet: View {
    private let credentialStore = SSHProfileCredentialStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SSHSessionStore.self) private var sshSessionStore

    let existing: SSHProfile?

    @State private var displayName  = ""
    @State private var host         = ""
    @State private var portString   = "22"
    @State private var username     = ""
    @State private var authType: SSHAuthType = .password

    @State private var password         = ""
    @State private var privateKeyPEM    = ""
    @State private var keyPassphrase    = ""

    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var showResetFingerprintConfirm = false
    @State private var hasAttemptedSubmit = false
    @State private var saveError: String?

    private var isEditing: Bool { existing != nil }

    private var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var port: Int? {
        let trimmed = portString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 1 && value <= 65535 else {
            return nil
        }
        return value
    }

    private var isValidPort: Bool {
        port != nil
    }

    private var credentialMissing: Bool {
        switch authType {
        case .password:   password.isEmpty
        case .privateKey: privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var canSave: Bool {
        !trimmedHost.isEmpty && !trimmedUsername.isEmpty && !credentialMissing && isValidPort
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                authSection
                fingerprintSection

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Remove Server", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Server" : "New SSH Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        hasAttemptedSubmit = true
                        guard canSave else { return }
                        isSaving = true
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .confirmationDialog(
                "Remove \"\(existing?.displayName ?? "this server")\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the server and its stored credentials.")
            }
            .confirmationDialog(
                "Reset trusted fingerprint?",
                isPresented: $showResetFingerprintConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Fingerprint", role: .destructive) { resetFingerprint() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The next connection will ask you to trust this host again.")
            }
            .alert(
                "Couldn't Save Server",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                ),
                presenting: saveError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .task { await loadExisting() }
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        Section {
            TextField("Display Name (optional)", text: $displayName)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            TextField("Host or IP", text: $host)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField("Port", text: $portString)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            TextField("Username", text: $username)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                #endif
                .autocorrectionDisabled()
        } header: {
            Text("Server")
        } footer: {
            if hasAttemptedSubmit && trimmedHost.isEmpty {
                fieldError("Host is required.")
            } else if hasAttemptedSubmit && trimmedUsername.isEmpty {
                fieldError("Username is required.")
            } else if hasAttemptedSubmit && !isValidPort {
                fieldError("Port must be a number between 1 and 65535.")
            } else {
                Text("Example: 192.168.1.1 or myserver.local")
            }
        }
    }

    private var authSection: some View {
        Section {
            Picker("Method", selection: $authType) {
                ForEach(SSHAuthType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            switch authType {
            case .password:
                SecureField("Password", text: $password)
                    #if os(iOS)
                    .textContentType(.password)
                    #endif

            case .privateKey:
                TextField(
                    "Paste PEM contents (e.g. begin with -----BEGIN OPENSSH PRIVATE KEY-----)",
                    text: $privateKeyPEM,
                    axis: .vertical
                )
                .lineLimit(4...10)
                .font(.system(.footnote, design: .monospaced))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

                SecureField("Passphrase (optional)", text: $keyPassphrase)
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
            }
        } header: {
            Text("Authentication")
        } footer: {
            if hasAttemptedSubmit && credentialMissing {
                fieldError(authType == .password
                    ? "Password is required."
                    : "Private key is required.")
            } else {
                Text("Credentials are stored securely in the system Keychain.")
            }
        }
    }

    @ViewBuilder
    private var fingerprintSection: some View {
        if let existing, existing.knownHostFingerprint != nil {
            Section {
                Button(role: .destructive) {
                    showResetFingerprintConfirm = true
                } label: {
                    Label("Reset Trusted Fingerprint", systemImage: "lock.open")
                }
            } footer: {
                Text("Reset this if the server was rebuilt or its host key intentionally changed.")
            }
        }
    }

    private func fieldError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
            .font(.footnote)
    }

    // MARK: - Load existing

    private func loadExisting() async {
        guard let profile = existing else { return }
        displayName = profile.displayName
        host        = profile.host
        portString  = String(profile.port)
        username    = profile.username
        authType    = profile.authType

        do {
            switch profile.authType {
            case .password:
                password = try await KeychainHelper.shared.read(key: profile.passwordKey) ?? ""
            case .privateKey:
                privateKeyPEM = try await KeychainHelper.shared.read(key: profile.privateKeyKey) ?? ""
                keyPassphrase = try await KeychainHelper.shared.read(key: profile.passphraseKey) ?? ""
            }
        } catch {
            saveError = "Could not load saved credentials from Keychain: \(error.localizedDescription)"
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        guard let capturedPort = port else {
            saveError = "Port must be a number between 1 and 65535."
            return
        }

        // Capture immutable snapshot of all form state before any async work
        let capturedHost = trimmedHost
        let capturedUsername = trimmedUsername
        let capturedAuthType = authType
        let capturedPassword = password
        let capturedPrivateKeyPEM = privateKeyPEM.trimmingCharacters(in: .whitespacesAndNewlines)
        let capturedKeyPassphrase = keyPassphrase
        let resolvedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? capturedHost
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing {
            // Close any active sessions for this profile before editing
            await sshSessionStore.closeSessions(for: existing.id)

            let previousDisplayName = existing.displayName
            let previousHost = existing.host
            let previousPort = existing.port
            let previousUsername = existing.username
            let previousAuthTypeRaw = existing.authTypeRaw
            let previousFingerprint = existing.knownHostFingerprint

            do {
                // Snapshot existing credentials; if this fails, abort the save
                let previousCredentials = try await credentialStore.snapshotCredentials(for: existing)

                do {
                    try await credentialStore.writeCredentials(
                        for: existing,
                        authType: capturedAuthType,
                        password: capturedPassword,
                        privateKeyPEM: capturedPrivateKeyPEM,
                        keyPassphrase: capturedKeyPassphrase
                    )
                    existing.displayName = resolvedName
                    existing.host = capturedHost
                    existing.port = capturedPort
                    existing.username = capturedUsername
                    existing.authTypeRaw = capturedAuthType.rawValue

                    // Clear fingerprint if SSH endpoint changed
                    if capturedHost != previousHost || capturedPort != previousPort {
                        existing.knownHostFingerprint = nil
                    }

                    try modelContext.save()
                    dismiss()
                } catch {
                    // Restore credentials on failure
                    existing.displayName = previousDisplayName
                    existing.host = previousHost
                    existing.port = previousPort
                    existing.username = previousUsername
                    existing.authTypeRaw = previousAuthTypeRaw
                    existing.knownHostFingerprint = previousFingerprint
                    modelContext.rollback()
                    do {
                        try await credentialStore.restoreCredentials(previousCredentials, for: existing)
                        saveError = error.localizedDescription
                    } catch let restoreError {
                        saveError = "Failed to save: \(error.localizedDescription). Additionally, failed to restore credentials: \(restoreError.localizedDescription)"
                    }
                }
            } catch {
                // Keychain snapshot failed; abort without changing anything
                saveError = "Could not read existing credentials: \(error.localizedDescription)"
            }
            return
        }

        let profile = SSHProfile(
                displayName: resolvedName,
                host: capturedHost,
                port: capturedPort,
                username: capturedUsername,
                authType: capturedAuthType
        )

        do {
            try await credentialStore.writeCredentials(
                for: profile,
                authType: capturedAuthType,
                password: capturedPassword,
                privateKeyPEM: capturedPrivateKeyPEM,
                keyPassphrase: capturedKeyPassphrase
            )
            modelContext.insert(profile)
            try modelContext.save()
            dismiss()
        } catch let saveFailure {
            modelContext.rollback()
            do {
                try await credentialStore.clearCredentials(for: profile)
                saveError = saveFailure.localizedDescription
            } catch let cleanupFailure {
                saveError = "Failed to save profile: \(saveFailure.localizedDescription). Cleanup also failed: \(cleanupFailure.localizedDescription)"
            }
        }
    }

    // MARK: - Delete

    private func delete() async {
        guard let profile = existing else { return }

        // Snapshot credentials first
        let credentialSnapshot: SSHCredentialSnapshot
        do {
            credentialSnapshot = try await credentialStore.snapshotCredentials(for: profile)
        } catch {
            saveError = "Could not delete profile: \(error.localizedDescription)"
            return
        }

        // Perform deletions
        do {
            try await credentialStore.clearCredentials(for: profile)
            modelContext.delete(profile)
            try modelContext.save()

            // Only tear down sessions after successful delete
            await sshSessionStore.closeSessions(for: profile.id)

            dismiss()
        } catch let deleteFailure {
            modelContext.rollback()
            do {
                try await credentialStore.restoreCredentials(credentialSnapshot, for: profile)
            } catch {
                saveError = "Could not delete profile: \(deleteFailure.localizedDescription)"
                return
            }
            saveError = "Could not delete profile: \(deleteFailure.localizedDescription)"
        }
    }

    private func resetFingerprint() {
        guard let existing else { return }
        existing.knownHostFingerprint = nil
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveError = "Could not reset fingerprint: \(error.localizedDescription)"
        }
    }
}
