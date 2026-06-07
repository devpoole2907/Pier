import SwiftUI

struct RedirectionHostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMRedirectionHostsViewModel
    let existing: NPMRedirectionHost?

    @State private var domainNamesText: String = ""
    @State private var forwardHTTPCode: Int = 301
    @State private var forwardScheme: String = "auto"
    @State private var forwardDomainName: String = ""
    @State private var preservePath: Bool = true
    @State private var sslForced: Bool = false
    @State private var hstsEnabled: Bool = false
    @State private var hstsSubdomains: Bool = false
    @State private var http2Support: Bool = false
    @State private var blockExploits: Bool = true
    @State private var advancedConfig: String = ""
    @State private var isSaving = false
    @State private var saveError: NPMError?

    private let schemes = ["auto", "http", "https"]
    private let httpCodes = [300, 301, 302, 303, 304, 307, 308]
    private var isEditing: Bool { existing != nil }

    init(viewModel: NPMRedirectionHostsViewModel, existing: NPMRedirectionHost?) {
        self.viewModel = viewModel
        self.existing = existing
    }

    var body: some View {
        Form {
            Section("Domains") {
                TextField("example.com, www.example.com", text: $domainNamesText)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }

            Section("Redirect") {
                Picker("HTTP Code", selection: $forwardHTTPCode) {
                    ForEach(httpCodes, id: \.self) { code in
                        Text("\(code)").tag(code)
                    }
                }

                Picker("Scheme", selection: $forwardScheme) {
                    ForEach(schemes, id: \.self) { Text($0) }
                }

                TextField("Target domain", text: $forwardDomainName)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                Toggle("Preserve path", isOn: $preservePath)
            }

            Section("SSL") {
                Toggle("Force SSL", isOn: $sslForced)
                Toggle("HSTS", isOn: $hstsEnabled)
                if hstsEnabled {
                    Toggle("HSTS Subdomains", isOn: $hstsSubdomains)
                }
                Toggle("HTTP/2 Support", isOn: $http2Support)
            }

            Section("Advanced") {
                Toggle("Block Common Exploits", isOn: $blockExploits)
                TextField("Advanced config", text: $advancedConfig, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.caption.monospaced())
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Save failed")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Redirection" : "New Redirection")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(isSaving || !canSave)
            }
        }
        .task { await loadExisting() }
    }

    private var domainNames: [String] {
        domainNamesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var canSave: Bool { !domainNames.isEmpty && !forwardDomainName.isEmpty }

    private func loadExisting() async {
        guard let host = existing else { return }
        domainNamesText = host.domain_names.joined(separator: ", ")
        forwardHTTPCode = host.forward_http_code
        forwardScheme = host.forward_scheme ?? "auto"
        forwardDomainName = host.forward_domain_name
        preservePath = host.preserve_path?.boolValue ?? true
        sslForced = host.ssl_forced?.boolValue ?? false
        hstsEnabled = host.hsts_enabled?.boolValue ?? false
        hstsSubdomains = host.hsts_subdomains?.boolValue ?? false
        http2Support = host.http2_support?.boolValue ?? false
        blockExploits = host.block_exploits?.boolValue ?? true
        advancedConfig = host.advanced_config ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if let existing {
            var base = NPMRedirectionHostUpdate(from: existing)
            base = NPMRedirectionHostUpdate(
                domainNames: domainNames,
                forwardHTTPCode: forwardHTTPCode,
                forwardScheme: forwardScheme,
                forwardDomainName: forwardDomainName,
                preservePath: preservePath,
                certificateID: base.certificate_id,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                blockExploits: blockExploits,
                advancedConfig: advancedConfig,
                enabled: base.enabled.boolValue
            )
            await viewModel.save(update: existing.id, payload: base)
        } else {
            let payload = NPMRedirectionHostCreate(
                domainNames: domainNames,
                forwardHTTPCode: forwardHTTPCode,
                forwardScheme: forwardScheme,
                forwardDomainName: forwardDomainName,
                preservePath: preservePath,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                blockExploits: blockExploits,
                advancedConfig: advancedConfig
            )
            await viewModel.save(create: payload)
        }

        if viewModel.loadError == nil { dismiss() } else { saveError = viewModel.loadError }
    }
}
