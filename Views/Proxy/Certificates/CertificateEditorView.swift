import SwiftUI

/// Requests a new Let's Encrypt certificate. Supports the **HTTP-01** challenge
/// (NPM serves `/.well-known/acme-challenge` on :80 — domains must point here and
/// be publicly reachable) and the **DNS-01** challenge (required for wildcard certs
/// and hosts not reachable on :80), where the user picks a certbot DNS provider and
/// supplies that provider's API credentials.
struct CertificateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMCertificatesViewModel
    /// Called with the new certificate after a successful request (before dismissal),
    /// so a presenter (e.g. the proxy-host editor) can auto-select it.
    var onCreated: ((NPMCertificate) -> Void)?

    private enum ChallengeType: String, CaseIterable, Identifiable {
        case http = "HTTP"
        case dns = "DNS"
        var id: String { rawValue }
    }

    @State private var domainNamesText: String = ""
    @State private var letsencryptEmail: String = ""
    @State private var challenge: ChallengeType = .http
    @State private var selectedProvider: CertbotDNSProvider?
    @State private var credentials: String = ""
    @State private var propagationSecondsText: String = ""
    @State private var agreeToS: Bool = false
    @State private var isSaving = false
    @State private var saveError: NPMError?

    init(viewModel: NPMCertificatesViewModel, onCreated: ((NPMCertificate) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onCreated = onCreated
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

            Section {
                TextField("Email", text: $letsencryptEmail)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Let's Encrypt")
            } footer: {
                Text(challenge == .dns
                     ? "DNS validation supports wildcard domains (*.example.com) and hosts not reachable on port 80."
                     : "Domains must resolve to this NPM instance and be reachable on port 80 for the HTTP challenge to succeed.")
            }

            Section("Challenge") {
                Picker("Method", selection: $challenge) {
                    Text("HTTP").tag(ChallengeType.http)
                    Text("DNS").tag(ChallengeType.dns)
                }
                .pickerStyle(.segmented)
            }

            if challenge == .dns {
                dnsSections
            }

            Section {
                Toggle("I agree to the Let's Encrypt Terms of Service", isOn: $agreeToS)
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Request failed")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("New Certificate")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Request") }
                }
                .disabled(isSaving || !canSave)
            }
        }
        .onChange(of: selectedProvider) { _, provider in
            // Pre-fill the editor with the provider's example credentials block so
            // the user just replaces the placeholder values.
            credentials = provider?.credentialsTemplate ?? ""
        }
    }

    @ViewBuilder
    private var dnsSections: some View {
        Section("DNS Provider") {
            Picker("Provider", selection: $selectedProvider) {
                Text("Select…").tag(CertbotDNSProvider?.none)
                ForEach(CertbotDNSCatalog.providers) { provider in
                    Text(provider.name).tag(CertbotDNSProvider?.some(provider))
                }
            }
        }

        if selectedProvider != nil {
            Section {
                TextField("Credentials", text: $credentials, axis: .vertical)
                    .lineLimit(4...12)
                    .font(.caption.monospaced())
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            } header: {
                Text("Credentials")
            } footer: {
                Text("Replace the placeholder values with your provider's API credentials. These are sent to NPM, which stores them to perform the DNS challenge.")
            }

            Section {
                TextField("Propagation seconds (optional)", text: $propagationSecondsText)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            } footer: {
                Text("How long to wait for DNS to propagate before validation. Leave blank for the provider default.")
            }
        }
    }

    private var domainNames: [String] {
        domainNamesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        guard !domainNames.isEmpty, letsencryptEmail.contains("@"), agreeToS else { return false }
        if challenge == .dns {
            guard selectedProvider != nil,
                  !credentials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        }
        return true
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let payload: NPMCertificateCreate
        switch challenge {
        case .http:
            payload = NPMCertificateCreate(domainNames: domainNames, letsencryptEmail: letsencryptEmail)
        case .dns:
            guard let provider = selectedProvider else { return }
            payload = NPMCertificateCreate(
                domainNames: domainNames,
                letsencryptEmail: letsencryptEmail,
                dnsProvider: provider.id,
                dnsProviderCredentials: credentials,
                propagationSeconds: Int(propagationSecondsText.trimmingCharacters(in: .whitespaces))
            )
        }

        await viewModel.save(create: payload)

        if viewModel.loadError == nil {
            if let created = viewModel.lastCreated { onCreated?(created) }
            dismiss()
        } else {
            saveError = viewModel.loadError
        }
    }
}
