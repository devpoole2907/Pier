import SwiftUI

struct StreamEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMStreamsViewModel
    let existing: NPMStream?

    @State private var incomingPort: String = ""
    @State private var forwardingHost: String = ""
    @State private var forwardingPort: String = ""
    @State private var tcpForwarding: Bool = true
    @State private var udpForwarding: Bool = false
    @State private var isSaving = false
    @State private var saveError: NPMError?

    private var isEditing: Bool { existing != nil }

    init(viewModel: NPMStreamsViewModel, existing: NPMStream?) {
        self.viewModel = viewModel
        self.existing = existing
    }

    var body: some View {
        Form {
            Section("Incoming") {
                TextField("Port", text: $incomingPort)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            Section("Forwarding") {
                TextField("Host", text: $forwardingHost)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("Port", text: $forwardingPort)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }

            Section("Protocol") {
                Toggle("TCP", isOn: $tcpForwarding)
                Toggle("UDP", isOn: $udpForwarding)
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Save failed").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Stream" : "New Stream")
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

    private var canSave: Bool {
        Int(incomingPort) != nil && !forwardingHost.isEmpty && Int(forwardingPort) != nil
    }

    private func loadExisting() async {
        guard let stream = existing else { return }
        incomingPort = String(stream.incoming_port)
        forwardingHost = stream.forwarding_host
        forwardingPort = String(stream.forwarding_port)
        tcpForwarding = stream.tcp_forwarding?.boolValue ?? true
        udpForwarding = stream.udp_forwarding?.boolValue ?? false
    }

    private func save() async {
        guard let inPort = Int(incomingPort), let fwdPort = Int(forwardingPort) else { return }
        isSaving = true
        defer { isSaving = false }

        if let existing {
            let prev = NPMStreamUpdate(from: existing)
            let updated = NPMStreamUpdate(
                incomingPort: inPort,
                forwardingHost: forwardingHost,
                forwardingPort: fwdPort,
                tcpForwarding: tcpForwarding,
                udpForwarding: udpForwarding,
                certificateID: prev.certificate_id,
                enabled: prev.enabled.boolValue
            )
            await viewModel.save(update: existing.id, payload: updated)
        } else {
            let payload = NPMStreamCreate(
                incomingPort: inPort,
                forwardingHost: forwardingHost,
                forwardingPort: fwdPort,
                tcpForwarding: tcpForwarding,
                udpForwarding: udpForwarding
            )
            await viewModel.save(create: payload)
        }

        if viewModel.loadError == nil { dismiss() } else { saveError = viewModel.loadError }
    }
}
