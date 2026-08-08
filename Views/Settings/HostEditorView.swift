import SwiftUI
import SwiftData
import OSLog

private let hostEditorLogger = Logger(subsystem: "com.poole.james.pier", category: "hosts.editor")

/// Configures Pier's single Komodo Core connection. Tests the connection before saving so the
/// user knows the API key/secret work.
struct HostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(HostManager.self) private var hostManager

    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    @State private var allowsInsecureTLS: Bool
    @State private var connectionTest: ConnectionTestState = .idle
    @State private var isShowingRemoveConfirmation = false
    @FocusState private var focusedField: Field?
    @State private var urlValidationMessage: String?

    private let existingHost: Host?

    init(host: Host?) {
        self.existingHost = host
        _name = State(initialValue: host?.name ?? "")
        _baseURL = State(initialValue: host?.baseURL ?? "http://")
        _allowsInsecureTLS = State(initialValue: host?.allowsInsecureTLS ?? false)
    }

    enum Field: Hashable {
        case name, baseURL, apiKey, apiSecret
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

                TextField("Base URL", text: $baseURL, prompt: Text("http://10.0.0.5:9120"))
                    .focused($focusedField, equals: .baseURL)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .submitLabel(.next)
                    #endif
                    .onSubmit { focusedField = .apiKey }
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
                TextField("API Key", text: $apiKey)
                    .focused($focusedField, equals: .apiKey)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .submitLabel(.next)
                    #endif
                    .onSubmit { focusedField = .apiSecret }

                SecureField("API Secret", text: $apiSecret)
                    .focused($focusedField, equals: .apiSecret)
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

            if existingHost != nil {
                Section {
                    Button("Remove Komodo Connection", systemImage: "trash", role: .destructive) {
                        isShowingRemoveConfirmation = true
                    }
                    .confirmationDialog(
                        "Remove Komodo connection?",
                        isPresented: $isShowingRemoveConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Remove Connection", role: .destructive, action: removeConnection)
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Pier will remove the Core configuration and its saved credentials. Servers and containers managed by Komodo are not affected.")
                    }
                }
            }
        }
        .navigationTitle(existingHost == nil ? "Connect Komodo" : "Edit Komodo")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .onAppear {
            if focusedField == nil {
                focusedField = name.isEmpty ? .name : .apiSecret
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
        !baseURL.isEmpty && !apiKey.isEmpty && !apiSecret.isEmpty && connectionTest != .testing
    }

    private var canSave: Bool {
        !name.isEmpty
            && !baseURL.isEmpty
            && (existingHost != nil || (!apiKey.isEmpty && !apiSecret.isEmpty))
            && connectionTest != .testing
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
        hostEditorLogger.info("Testing Komodo connection")
        do {
            let candidate = Host(
                name: name.isEmpty ? "Test" : name,
                baseURL: baseURL,
                allowsInsecureTLS: allowsInsecureTLS
            )
            let client = try KomodoClient(
                host: candidate,
                apiKey: apiKey,
                apiSecret: apiSecret,
                allowsInsecureTLS: allowsInsecureTLS
            )
            _ = try await client.testConnection()
            connectionTest = .success
            hostEditorLogger.info("Connection test succeeded")
        } catch let error as KomodoError {
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
            if existingHost == nil {
                let existingHostCount = try modelContext.fetchCount(FetchDescriptor<Host>())
                guard existingHostCount == 0 else {
                    connectionTest = .failure("A Komodo Core is already configured. Edit it in Settings.")
                    return
                }
            }

            let host: Host
            let hasNewCredentials = !apiKey.isEmpty && !apiSecret.isEmpty

            if let existing = existingHost {
                existing.name = name
                existing.baseURL = baseURL
                existing.allowsInsecureTLS = allowsInsecureTLS
                host = existing
            } else {
                host = Host(
                    name: name,
                    baseURL: baseURL,
                    allowsInsecureTLS: allowsInsecureTLS
                )
                modelContext.insert(host)
            }

            hostManager.invalidateClient(for: host)
            if hasNewCredentials {
                try await hostManager.authenticate(host: host, apiKey: apiKey, apiSecret: apiSecret)
            }
            try modelContext.save()
            await hostManager.setActive(host)
            hostEditorLogger.info("Saved host configuration")
            dismiss()
        } catch let error as KomodoError {
            connectionTest = .failure(connectionFailureMessage(for: error))
            hostEditorLogger.error("Failed to save host configuration: \(error.localizedDescription, privacy: .private)")
        } catch {
            connectionTest = .failure(error.localizedDescription)
            hostEditorLogger.error("Failed to save host configuration: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func removeConnection() {
        guard let existingHost else { return }
        hostManager.forget(existingHost)
        modelContext.delete(existingHost)
        do {
            try modelContext.save()
            hostEditorLogger.info("Removed host configuration")
            dismiss()
        } catch {
            connectionTest = .failure(error.localizedDescription)
            hostEditorLogger.error("Failed to remove host configuration: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func connectionFailureMessage(for error: KomodoError) -> String {
        if case .serverError(_, let message) = error,
           let message {
            return message
        }
        return error.errorDescription ?? "Connection failed"
    }
}
