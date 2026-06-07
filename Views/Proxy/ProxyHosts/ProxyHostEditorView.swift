import SwiftUI

struct ProxyHostEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMProxyHostsViewModel
    let existing: NPMProxyHost?

    @State private var domainNamesText: String = ""
    @State private var forwardScheme: String = "http"
    @State private var forwardHost: String = ""
    @State private var forwardPort: String = "80"
    @State private var sslForced: Bool = false
    @State private var hstsEnabled: Bool = false
    @State private var hstsSubdomains: Bool = false
    @State private var http2Support: Bool = false
    @State private var allowWebsocketUpgrade: Bool = false
    @State private var blockExploits: Bool = true
    @State private var cachingEnabled: Bool = false
    @State private var advancedConfig: String = ""
    @State private var isSaving = false
    @State private var saveError: NPMError?

    @State private var certificates: [NPMCertificate] = []
    @State private var accessLists: [NPMAccessList] = []
    @State private var selectedCertificateID: Int?
    @State private var selectedAccessListID: Int?
    @State private var isLoadingPickers = false

    @State private var locations: [EditableLocation] = []

    @State private var certEditorContext: CertEditorContext?

    private let schemes = ["http", "https"]

    private var isEditing: Bool { existing != nil }

    /// Identifiable wrapper so the inline cert editor is driven by `.sheet(item:)`,
    /// which guarantees a non-nil value in the content closure (avoids a blank first present).
    private struct CertEditorContext: Identifiable {
        let id = UUID()
        let viewModel: NPMCertificatesViewModel
    }

    /// Local, editable mirror of an `NPMLocation` (string ports for `TextField` binding).
    private struct EditableLocation: Identifiable {
        let id = UUID()
        var path: String = "/"
        var forwardScheme: String = "http"
        var forwardHost: String = ""
        var forwardPort: String = "80"
        var forwardPath: String = ""
        var advancedConfig: String = ""
    }

    init(viewModel: NPMProxyHostsViewModel, existing: NPMProxyHost?) {
        self.viewModel = viewModel
        self.existing = existing
    }

    var body: some View {
        Form {
            Section("Domains") {
                TextField("example.com, *.example.com", text: $domainNamesText)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }

            Section("Forward") {
                Picker("Scheme", selection: $forwardScheme) {
                    ForEach(schemes, id: \.self) { Text($0) }
                }

                TextField("Forward host", text: $forwardHost)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("Forward port", text: $forwardPort)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            Section("SSL") {
                Toggle("Force SSL", isOn: $sslForced)
                Toggle("HSTS", isOn: $hstsEnabled)
                if hstsEnabled {
                    Toggle("HSTS Subdomains", isOn: $hstsSubdomains)
                }
                Toggle("HTTP/2 Support", isOn: $http2Support)
            }

            Section("Certificate") {
                if isLoadingPickers {
                    ProgressView()
                } else {
                    Menu {
                        Button {
                            certEditorContext = CertEditorContext(viewModel: viewModel.makeCertificatesViewModel())
                        } label: {
                            Label("Request New Certificate…", systemImage: "plus.circle")
                        }

                        Divider()

                        // Rendered inline inside the menu with a checkmark on the selection.
                        Picker("Certificate", selection: $selectedCertificateID) {
                            Text("None").tag(Int?.none)
                            ForEach(certificates) { cert in
                                Text(cert.nice_name).tag(Int?.some(cert.id))
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCertificateName)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Section("Access List") {
                if isLoadingPickers {
                    ProgressView()
                } else {
                    Picker("Access List", selection: $selectedAccessListID) {
                        Text("None").tag(Int?.none)
                        ForEach(accessLists) { list in
                            Text(list.name).tag(Int?.some(list.id))
                        }
                    }
                }
            }

            Section("Features") {
                Toggle("Websocket Support", isOn: $allowWebsocketUpgrade)
                Toggle("Block Common Exploits", isOn: $blockExploits)
                Toggle("Cache Assets", isOn: $cachingEnabled)
            }

            locationsSections

            Section("Advanced") {
                TextField("Advanced config", text: $advancedConfig, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.caption.monospaced())
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Save failed")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Proxy Host" : "New Proxy Host")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || !canSave)
            }
        }
        .sheet(item: $certEditorContext) { context in
            NavigationStack {
                CertificateEditorView(viewModel: context.viewModel) { cert in
                    Task {
                        await loadPickers()
                        selectedCertificateID = cert.id
                    }
                }
            }
        }
        .task { await loadExisting() }
    }

    @ViewBuilder
    private var locationsSections: some View {
        Section {
            if locations.isEmpty {
                Text("No custom locations")
                    .foregroundStyle(.secondary)
            }
            Button("Add Location", systemImage: "plus") {
                locations.append(EditableLocation())
            }
        } header: {
            Text("Custom Locations")
        } footer: {
            Text("Route specific paths to different backends. The main forward above handles everything else.")
        }

        ForEach($locations) { $location in
            Section("Location \(location.path.isEmpty ? "/" : location.path)") {
                TextField("Path (e.g. /api)", text: $location.path)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                Picker("Scheme", selection: $location.forwardScheme) {
                    ForEach(schemes, id: \.self) { Text($0) }
                }

                TextField("Forward host", text: $location.forwardHost)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("Forward port", text: $location.forwardPort)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                TextField("Forward path (optional)", text: $location.forwardPath)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("Advanced config", text: $location.advancedConfig, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.caption.monospaced())

                Button("Remove Location", systemImage: "trash", role: .destructive) {
                    locations.removeAll { $0.id == location.id }
                }
            }
        }
    }

    private var selectedCertificateName: String {
        guard let id = selectedCertificateID,
              let cert = certificates.first(where: { $0.id == id }) else { return "None" }
        return cert.nice_name
    }

    private var domainNames: [String] {
        domainNamesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !domainNames.isEmpty && !forwardHost.isEmpty && !forwardPort.isEmpty && Int(forwardPort) != nil
    }

    private func loadExisting() async {
        await loadPickers()

        guard let host = existing else { return }
        domainNamesText = host.domain_names.joined(separator: ", ")
        forwardScheme = host.forward_scheme ?? "http"
        forwardHost = host.forward_host
        forwardPort = String(host.forward_port)
        sslForced = host.ssl_forced?.boolValue ?? false
        hstsEnabled = host.hsts_enabled?.boolValue ?? false
        hstsSubdomains = host.hsts_subdomains?.boolValue ?? false
        http2Support = host.http2_support?.boolValue ?? false
        allowWebsocketUpgrade = host.allow_websocket_upgrade?.boolValue ?? false
        blockExploits = host.block_exploits?.boolValue ?? true
        cachingEnabled = host.caching_enabled?.boolValue ?? false
        advancedConfig = host.advanced_config ?? ""
        selectedCertificateID = host.certificate_id == 0 ? nil : host.certificate_id
        selectedAccessListID = host.access_list_id == 0 ? nil : host.access_list_id
        locations = (host.locations ?? []).map { loc in
            EditableLocation(
                path: loc.path,
                forwardScheme: loc.forward_scheme ?? "http",
                forwardHost: loc.forward_host,
                forwardPort: String(loc.forward_port),
                forwardPath: loc.forward_path ?? "",
                advancedConfig: loc.advanced_config ?? ""
            )
        }
    }

    private func loadPickers() async {
        isLoadingPickers = true
        defer { isLoadingPickers = false }
        async let fetchedCerts = viewModel.fetchCertificates()
        async let fetchedLists = viewModel.fetchAccessLists()
        certificates = await fetchedCerts
        accessLists = await fetchedLists
    }

    /// Maps the editable rows into create payloads, dropping incomplete entries.
    private var locationPayloads: [NPMLocationCreate] {
        locations.compactMap { loc in
            let path = loc.path.trimmingCharacters(in: .whitespaces)
            let host = loc.forwardHost.trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty, !host.isEmpty, let port = Int(loc.forwardPort) else { return nil }
            let forwardPath = loc.forwardPath.trimmingCharacters(in: .whitespaces)
            return NPMLocationCreate(
                path: path,
                forwardScheme: loc.forwardScheme,
                forwardHost: host,
                forwardPort: port,
                forwardPath: forwardPath.isEmpty ? nil : forwardPath,
                advancedConfig: loc.advancedConfig
            )
        }
    }

    private func save() async {
        guard let port = Int(forwardPort) else { return }
        isSaving = true
        defer { isSaving = false }

        if let existing {
            let previous = NPMProxyHostUpdate(from: existing)
            let updated = NPMProxyHostUpdate(
                domainNames: domainNames,
                forwardScheme: forwardScheme,
                forwardHost: forwardHost,
                forwardPort: port,
                certificateID: selectedCertificateID,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                allowWebsocketUpgrade: allowWebsocketUpgrade,
                blockExploits: blockExploits,
                cachingEnabled: cachingEnabled,
                accessListID: selectedAccessListID,
                advancedConfig: advancedConfig,
                locations: locationPayloads,
                enabled: previous.enabled.boolValue
            )
            await viewModel.save(update: existing.id, payload: updated)
        } else {
            let payload = NPMProxyHostCreate(
                domainNames: domainNames,
                forwardScheme: forwardScheme,
                forwardHost: forwardHost,
                forwardPort: port,
                certificateID: selectedCertificateID,
                sslForced: sslForced,
                hstsEnabled: hstsEnabled,
                hstsSubdomains: hstsSubdomains,
                http2Support: http2Support,
                allowWebsocketUpgrade: allowWebsocketUpgrade,
                blockExploits: blockExploits,
                cachingEnabled: cachingEnabled,
                accessListID: selectedAccessListID,
                advancedConfig: advancedConfig,
                locations: locationPayloads
            )
            await viewModel.save(create: payload)
        }

        if viewModel.loadError == nil {
            dismiss()
        } else {
            saveError = viewModel.loadError
        }
    }
}
