import SwiftUI

/// Lets the user pick a specific Komodo resource (of the given `kind`) from the live lists
/// fetched for the active host, then opens a terminal for it.
///
/// Design choice: rather than tapping a row to navigate straight to the terminal (which is how
/// the main Terminals list works), this sheet uses an explicit select-then-confirm flow — tap a
/// row to highlight it, then tap "Open Terminal" — since it's reached from the "+" menu where the
/// user hasn't yet committed to a specific target.
struct KomodoTerminalConfigSheet: View {
    let kind: KomodoTerminalTarget.Kind
    let servers: [KomodoServer]
    let resources: TerminalsKomodoResources
    let onOpen: (KomodoTerminalTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    EmptyStateView(
                        title: "No \(kind.pluralLabel)",
                        systemImage: kind.systemImage,
                        message: "No \(kind.label.lowercased())s were found on the active Komodo host."
                    )
                } else {
                    List(candidates) { candidate in
                        Button {
                            selectedID = candidate.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(candidate.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedID == candidate.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose \(kind.label)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open Terminal") {
                        guard let target = selectedTarget else { return }
                        onOpen(target)
                    }
                    .disabled(selectedTarget == nil)
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

    private func serverName(for serverID: String) -> String {
        servers.first(where: { $0.id == serverID })?.name ?? serverID
    }
}
