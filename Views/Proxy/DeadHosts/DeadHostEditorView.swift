import SwiftUI

struct DeadHostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMDeadHostsViewModel
    let existing: NPMDeadHost?

    @State private var domainNamesText: String = ""
    @State private var sslForced: Bool = false
    @State private var hstsEnabled: Bool = false
    @State private var hstsSubdomains: Bool = false
    @State private var http2Support: Bool = false
    @State private var advancedConfig: String = ""
    @State private var isSaving = false
    @State private var saveError: NPMError?

    private var isEditing: Bool { existing != nil }

    init(viewModel: NPMDeadHostsViewModel, existing: NPMDeadHost?) {
        self.viewModel = viewModel
        self.existing = existing
    }

    var body: some View {
        Form {
            Section("Domains") {
                TextField("*.example.com", text: $domainNamesText)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
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
                TextField("Advanced config", text: $advancedConfig, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.caption.monospaced())
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Save failed").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit 404 Host" : "New 404 Host")
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

    private var canSave: Bool { !domainNames.isEmpty }

    private func loadExisting() async {
        guard let host = existing else { return }
        domainNamesText = host.domain_names.joined(separator: ", ")
        sslForced = host.ssl_forced?.boolValue ?? false
        hstsEnabled = host.hsts_enabled?.boolValue ?? false
        hstsSubdomains = host.hsts_subdomains?.boolValue ?? false
        http2Support = host.http2_support?.boolValue ?? false
        advancedConfig = host.advanced_config ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if let existing {
            let prev = NPMDeadHostUpdate(from: existing)
            let updated = NPMDeadHostUpdate(
                domainNames: domainNames,
                certificateID: prev.certificate_id,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                advancedConfig: advancedConfig,
                enabled: prev.enabled.boolValue
            )
            await viewModel.save(update: existing.id, payload: updated)
        } else {
            let payload = NPMDeadHostCreate(
                domainNames: domainNames,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                advancedConfig: advancedConfig
            )
            await viewModel.save(create: payload)
        }

        if viewModel.loadError == nil { dismiss() } else { saveError = viewModel.loadError }
    }
}
