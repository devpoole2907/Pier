import SwiftUI

/// Lets the user pick a specific Komodo resource (of the given `kind`) from the live lists
/// fetched for the active host, then adds it as a saved terminal target on the Terminals tab.
///
/// Reached from the "+" menu: the user picks a resource here, optionally a stack service / mode /
/// terminal name, taps "Add", and it's pinned to the Terminals list (tapping it there opens the
/// live terminal). Select-then-confirm rather than tap-to-commit since the picker shows the full
/// live inventory.
struct KomodoTerminalConfigSheet: View {
    let kind: KomodoTerminalTarget.Kind
    let servers: [KomodoServer]
    let resources: TerminalsKomodoResources
    let onAdd: (KomodoTerminalTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?
    @State private var selectedService: String?
    @State private var mode: KomodoTerminalTarget.Mode = .exec
    @State private var terminalName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a \(kind.label)") {
                    if candidates.isEmpty {
                        Text("No \(kind.label.lowercased())s were found on the active Komodo host.")
                            .foregroundStyle(.secondary)
                    } else {
                        // A navigation-link picker keeps the form compact so Service / Mode /
                        // Terminal name below stay on-screen instead of being pushed off by a long
                        // inventory list.
                        Picker(kind.label, selection: $selectedID) {
                            Text("Select…").tag(String?.none)
                            ForEach(candidates) { candidate in
                                Text(candidate.name).tag(Optional(candidate.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }

                if kind == .stack, let stack = selectedStack {
                    Section("Service") {
                        Picker("Service", selection: Binding(
                            get: { selectedService ?? stack.services.first?.service ?? "" },
                            set: { selectedService = $0 }
                        )) {
                            ForEach(stack.services) { service in
                                Text(service.service).tag(service.service)
                            }
                        }
                    }
                }

                if kind != .server {
                    Section("Mode") {
                        Picker("Mode", selection: $mode) {
                            ForEach(KomodoTerminalTarget.Mode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Terminal name") {
                    TextField("pier (optional)", text: $terminalName)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                }
            }
            .onChange(of: selectedID) { selectedService = nil }
            .navigationTitle("Choose \(kind.label)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let target = finalTarget else { return }
                        onAdd(target)
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }

    private var candidates: [KomodoTerminalTarget] {
        switch kind {
        case .server:
            servers.map {
                KomodoTerminalTarget(kind: .server, resourceID: $0.id, name: $0.name, subtitle: $0.state.label)
            }
        case .container:
            resources.containers.map {
                KomodoTerminalTarget(
                    kind: .container,
                    resourceID: $0.id,
                    name: $0.displayName,
                    subtitle: "\(serverName(for: $0.serverID)) • \($0.status)",
                    serverID: $0.serverID
                )
            }
        case .stack:
            resources.stacks.map {
                KomodoTerminalTarget(
                    kind: .stack,
                    resourceID: $0.id,
                    name: $0.name,
                    subtitle: "\(serverName(for: $0.serverID)) • \($0.state.label)",
                    serviceName: $0.services.first?.service
                )
            }
        case .deployment:
            resources.deployments.map {
                KomodoTerminalTarget(
                    kind: .deployment,
                    resourceID: $0.id,
                    name: $0.name,
                    subtitle: "\(serverName(for: $0.serverID)) • \($0.state.label)"
                )
            }
        }
    }

    private var selectedTarget: KomodoTerminalTarget? {
        candidates.first { $0.id == selectedID }
    }

    private var selectedStack: Stack? {
        guard let selectedTarget else { return nil }
        return resources.stacks.first { $0.id == selectedTarget.resourceID }
    }

    private var canAdd: Bool {
        guard selectedTarget != nil else { return false }
        if kind == .stack {
            return !(selectedService ?? selectedStack?.services.first?.service ?? "").isEmpty
        }
        return true
    }

    private var finalTarget: KomodoTerminalTarget? {
        guard var target = selectedTarget else { return nil }
        if kind == .stack {
            target.serviceName = selectedService ?? selectedStack?.services.first?.service
        }
        if kind != .server {
            target.mode = mode
        }
        let trimmedName = terminalName.trimmingCharacters(in: .whitespaces)
        target.terminalName = trimmedName.isEmpty ? nil : trimmedName
        return target
    }

    private func serverName(for serverID: String) -> String {
        servers.first(where: { $0.id == serverID })?.name ?? serverID
    }
}
