import SwiftUI
import SwiftData
import OSLog

private let hostEditorLogger = Logger(subsystem: "com.poole.james.pier", category: "hosts.editor")

/// Add/edit a Portainer host. Tests the connection before saving so the user knows credentials work.
struct HostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HostManager.self) private var hostManager

    @State private var name: String
    @State private var baseURL: String
    @State private var username: String
    @State private var password: String = ""
    @State private var allowsInsecureTLS: Bool
    @State private var connectionTest: ConnectionTestState = .idle
    @FocusState private var focusedField: Field?
    @State private var urlValidationMessage: String?

    private let existingHost: Host?

    init(host: Host?) {
        self.existingHost = host
        _name = State(initialValue: host?.name ?? "")
        _baseURL = State(initialValue: host?.baseURL ?? "https://")
        _username = State(initialValue: host?.username ?? "admin")
        _allowsInsecureTLS = State(initialValue: host?.allowsInsecureTLS ?? false)
    }

    enum Field: Hashable {
        case name, baseURL, username, password
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

                TextField("Base URL", text: $baseURL, prompt: Text("https://10.0.0.5:9443"))
                    .focused($focusedField, equals: .baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .submitLabel(.next)
                    #endif
                    .onSubmit { focusedField = .username }
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

            Section("Credentials") {
                TextField("Username", text: $username)
                    .focused($focusedField, equals: .username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .submitLabel(.next)
                    #endif
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $password)
                    .focused($focusedField, equals: .password)
                    #if os(iOS)
                    .submitLabel(.go)
                    #endif
                    .onSubmit { Task { await testConnection() } }
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
        .navigationTitle(existingHost == nil ? "Add host" : "Edit host")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .onAppear {
            if focusedField == nil {
                focusedField = name.isEmpty ? .name : .password
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
        !baseURL.isEmpty && !username.isEmpty && !password.isEmpty && connectionTest != .testing
    }

    private var canSave: Bool {
        !name.isEmpty
            && !baseURL.isEmpty
            && !username.isEmpty
            && (existingHost != nil || !password.isEmpty)
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
        hostEditorLogger.info("Testing Portainer connection for username \(username, privacy: .private)")
        do {
            let candidate = Host(
                name: name.isEmpty ? "Test" : name,
                baseURL: baseURL,
                username: username,
                allowsInsecureTLS: allowsInsecureTLS
            )
            let client = try PortainerClient(host: candidate, password: password, allowsInsecureTLS: allowsInsecureTLS)
            try await client.authenticate(password: password)
            _ = try await client.listEndpoints()
            connectionTest = .success
            hostEditorLogger.info("Connection test succeeded")
        } catch let error as PortainerError {
            connectionTest = .failure(connectionFailureMessage(for: error))
            hostEditorLogger.error("Connection test failed: \(error.localizedDescription, privacy: .private)")
        } catch {
            connectionTest = .failure(error.localizedDescription)
            hostEditorLogger.error("Connection test failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func save() async {
        hostEditorLogger.info("Saving host configuration")
        do {
            let host: Host
            if let existing = existingHost {
                existing.name = name
                existing.baseURL = baseURL
                existing.username = username
                existing.allowsInsecureTLS = allowsInsecureTLS
                host = existing
            } else {
                host = Host(
                    name: name,
                    baseURL: baseURL,
                    username: username,
                    allowsInsecureTLS: allowsInsecureTLS
                )
                try await hostManager.authenticate(host: host, password: password)
                modelContext.insert(host)
            }

            hostManager.invalidateClient(for: host)
            try modelContext.save()
            // If a password was supplied, authenticate so we have a JWT cached before dismissing.
            if existingHost != nil, !password.isEmpty {
                try await hostManager.authenticate(host: host, password: password)
            }
            await hostManager.setActive(host)
            hostEditorLogger.info("Saved host configuration")
            dismiss()
        } catch let error as PortainerError {
            connectionTest = .failure(connectionFailureMessage(for: error))
            hostEditorLogger.error("Failed to save host configuration: \(error.localizedDescription, privacy: .private)")
        } catch {
            connectionTest = .failure(error.localizedDescription)
            hostEditorLogger.error("Failed to save host configuration: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func connectionFailureMessage(for error: PortainerError) -> String {
        if case .serverError(_, let message) = error,
           let message {
            let lowered = message.lowercased()
            if lowered.contains("csrf token not found") || lowered.contains("origin invalid") {
                return "Portainer rejected the request before API auth. Use the Portainer root URL, not a login page or /api path."
            }
        }
        return error.errorDescription ?? "Connection failed"
    }
}
