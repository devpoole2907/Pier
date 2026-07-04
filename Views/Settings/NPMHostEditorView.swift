import SwiftUI
import SwiftData
import OSLog

private let npmEditorLogger = Logger(subsystem: "com.poole.james.pier", category: "npm.hosts.editor")

struct NPMHostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NPMHostManager.self) private var npmHostManager

    @State private var name: String
    @State private var baseURL: String
    @State private var authMethod: NPMAuthMethod
    @State private var identity: String
    @State private var secret: String = ""
    @State private var allowsInsecureTLS: Bool
    @State private var connectionTest: ConnectionTestState = .idle
    @FocusState private var focusedField: Field?
    @State private var urlValidationMessage: String?

    private let existingHost: NPMHost?

    init(host: NPMHost?) {
        self.existingHost = host
        _name = State(initialValue: host?.name ?? "")
        _baseURL = State(initialValue: host?.baseURL ?? "http://")
        _authMethod = State(initialValue: host?.authMethod ?? .password)
        _identity = State(initialValue: host?.identity ?? "")
        _allowsInsecureTLS = State(initialValue: host?.allowsInsecureTLS ?? false)
    }

    enum Field: Hashable {
        case name, baseURL, identity, secret
    }

    enum ConnectionTestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Display name", text: $name)
                    .focused($focusedField, equals: .name)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    #endif
                    .onSubmit { focusedField = .baseURL }

                TextField("Base URL", text: $baseURL, prompt: Text("http://10.0.0.5:81"))
                    .focused($focusedField, equals: .baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .submitLabel(.next)
                    #endif
                    .onSubmit {
                        if authMethod == .password {
                            focusedField = .identity
                        } else {
                            focusedField = .secret
                        }
                    }
                    .onChange(of: baseURL) { _, newValue in
                        urlValidationMessage = validateURL(newValue)
                    }

                if let message = urlValidationMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle(isOn: $allowsInsecureTLS) {
                    Label("Allow self-signed TLS", systemImage: "lock.open.trianglebadge.exclamationmark")
                }
            }

            Section("Authentication") {
                Picker("Auth method", selection: $authMethod) {
                    ForEach(NPMAuthMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if authMethod == .password {
                    TextField("Email", text: $identity)
                        .focused($focusedField, equals: .identity)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .submitLabel(.next)
                        #endif
                        .onSubmit { focusedField = .secret }

                    SecureField("Password", text: $secret)
                        .focused($focusedField, equals: .secret)
                        #if os(iOS)
                        .submitLabel(.go)
                        #endif
                        .onSubmit { Task { await testConnection() } }
                } else {
                    SecureField("Paste API token", text: $secret)
                        .focused($focusedField, equals: .secret)
                        #if os(iOS)
                        .submitLabel(.go)
                        #endif
                        .onSubmit { Task { await testConnection() } }
                }
            }

            Section {
                Button("Test connection", systemImage: "checkmark.circle") {
                    Task { await testConnection() }
                }
                .disabled(!canTest)
                .keyboardShortcut("t", modifiers: .command)

                connectionTestStatusView
            }
        }
        .navigationTitle(existingHost == nil ? "Add NPM host" : "Edit NPM host")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .onAppear {
            if focusedField == nil {
                focusedField = name.isEmpty ? .name : (authMethod == .password ? .identity : .secret)
            }
        }
    }

    @ViewBuilder
    private var connectionTestStatusView: some View {
        switch connectionTest {
        case .idle:
            EmptyView()
        case .testing:
            HStack {
                ProgressView()
                Text("Testing…")
                    .foregroundStyle(.secondary)
            }
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: dismiss.callAsFunction)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task { await save() }
            }
            .disabled(!canSave)
        }
    }

    private var canTest: Bool {
        let hasURL = !baseURL.isEmpty
        let hasCred = authMethod == .password ? (!identity.isEmpty && !secret.isEmpty) : !secret.isEmpty
        return hasURL && hasCred && connectionTest != .testing
    }

    private var canSave: Bool {
        !name.isEmpty && !baseURL.isEmpty && connectionTest != .testing
    }

    private func validateURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed) else {
            return "Not a valid URL."
        }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return "Scheme must be http or https."
        }
        guard url.host?.isEmpty == false else {
            return "URL must include a hostname."
        }
        return nil
    }

    private func testConnection() async {
        connectionTest = .testing
        npmEditorLogger.info("Testing NPM connection")
        do {
            let candidate = NPMHost(
                name: name.isEmpty ? "Test" : name,
                baseURL: baseURL,
                authMethod: authMethod,
                identity: identity,
                allowsInsecureTLS: allowsInsecureTLS
            )
            let client = try NPMClient(host: candidate, secret: secret, allowsInsecureTLS: allowsInsecureTLS)
            try await client.authenticate(secret: secret)
            _ = try await client.ping()
            connectionTest = .success
            npmEditorLogger.info("NPM connection test succeeded")
            InAppNotificationCenter.shared.showSuccess(title: "Connection Verified", message: candidate.name)
        } catch let error as NPMError {
            connectionTest = .failure(error.errorDescription ?? "Connection failed")
            npmEditorLogger.error("NPM connection test failed: \(error.localizedDescription, privacy: .private)")
            InAppNotificationCenter.shared.reportFailure("Verify Host", error: error)
        } catch {
            connectionTest = .failure(error.localizedDescription)
            npmEditorLogger.error("NPM connection test failed: \(error.localizedDescription, privacy: .private)")
            InAppNotificationCenter.shared.reportFailure("Verify Host", error: error)
        }
    }

    private func save() async {
        npmEditorLogger.info("Saving NPM host configuration")
        do {
            let isNewHost = existingHost == nil
            let host: NPMHost
            if let existing = existingHost {
                existing.name = name
                existing.baseURL = baseURL
                existing.authMethodRaw = authMethod.rawValue
                existing.identity = identity
                existing.allowsInsecureTLS = allowsInsecureTLS
                host = existing
            } else {
                host = NPMHost(
                    name: name,
                    baseURL: baseURL,
                    authMethod: authMethod,
                    identity: identity,
                    allowsInsecureTLS: allowsInsecureTLS
                )
                try await npmHostManager.authenticate(host: host, secret: secret)
                modelContext.insert(host)
            }

            npmHostManager.invalidateClient(for: host)
            try modelContext.save()
            if existingHost != nil, !secret.isEmpty {
                try await npmHostManager.authenticate(host: host, secret: secret)
            }
            await npmHostManager.setActive(host)
            npmEditorLogger.info("Saved NPM host configuration")
            InAppNotificationCenter.shared.showSuccess(title: isNewHost ? "Host Added" : "Host Saved", message: host.name)
            dismiss()
        } catch let error as NPMError {
            connectionTest = .failure(error.errorDescription ?? "Save failed")
            npmEditorLogger.error("Failed to save NPM host: \(error.localizedDescription, privacy: .private)")
            InAppNotificationCenter.shared.reportFailure("Save Host", error: error)
        } catch {
            connectionTest = .failure(error.localizedDescription)
            npmEditorLogger.error("Failed to save NPM host: \(error.localizedDescription, privacy: .private)")
            InAppNotificationCenter.shared.reportFailure("Save Host", error: error)
        }
    }
}
