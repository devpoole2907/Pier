import SwiftUI

/// One row in the container list. Shows name, status, image, and uptime/since.
struct ContainerRowView: View {
    let container: Container
    let actionState: ContainerActionState?
    /// Server name to show on the row, when the list is cross-server and not already grouped by
    /// server. `nil` hides it (single-server scope, or the "By server" grouped view).
    let serverName: String?

    init(container: Container, actionState: ContainerActionState? = nil, serverName: String? = nil) {
        self.container = container
        self.actionState = actionState
        self.serverName = serverName
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(container.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let serverName {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack")
                            .imageScale(.small)
                        Text(serverName)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if let statusText {
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let statsSummary {
                    Text(statsSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            statusBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var statusText: String? {
        if let actionState {
            return actionState.rowDetailText
        }
        return container.status.isEmpty ? nil : container.status
    }

    /// Compact CPU%/mem summary from Komodo's inline stats snapshot - shown only for running
    /// containers with a fresh snapshot, since raw strings are already display-ready.
    private var statsSummary: String? {
        guard actionState == nil, container.state == .running, let stats = container.stats else { return nil }
        let parts = [
            stats.cpuPercRaw.isEmpty ? nil : "\(stats.cpuPercRaw) CPU",
            stats.memPercRaw.isEmpty ? nil : "\(stats.memPercRaw) mem"
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var accessibilityStatusText: String {
        actionState?.displayName ?? container.state.displayName
    }

    private var accessibilityLabel: String {
        var label = "\(container.displayName), \(accessibilityStatusText), image \(container.image)"
        if let statsSummary {
            label += ", \(statsSummary)"
        }
        return label
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let actionState {
            StatusBadgeView(actionState: actionState)
        } else {
            StatusBadgeView(status: container.state)
        }
    }
}

struct SelectableContainerRow: View {
    let container: Container
    let viewModel: ContainerListViewModel
    let isSelecting: Bool
    var serverName: String? = nil

    var body: some View {
        let actionState = viewModel.actionState(for: container)
        if isSelecting {
            ContainerRowView(container: container, actionState: actionState, serverName: serverName)
                .tag(container.id)
        } else {
            NavigationLink(value: ContainerNavigationValue(containerID: container.id, serverID: container.serverID, displayName: container.displayName)) {
                ContainerRowView(container: container, actionState: actionState, serverName: serverName)
            }
            .tag(container.id)
            .disabled(actionState != nil)
            .swipeActions(edge: .trailing) {
                ContainerSwipeActions(container: container, viewModel: viewModel)
            }
            .contextMenu {
                ContainerContextMenu(container: container, viewModel: viewModel)
            }
            // Attached to the row (the same view that owns the context menu) and gated to this
            // container, so the dialog morphs out of the row's context-menu preview instead of
            // detaching from the parent list.
            .confirmationDialog(
                dialogTitle,
                isPresented: dialogPresented,
                titleVisibility: .visible,
                presenting: viewModel.pendingDestructiveAction
            ) { pending in
                Button(confirmLabel(for: pending.action), role: .destructive) {
                    Task { await viewModel.confirmDestructiveAction() }
                }
                Button("Cancel", role: .cancel) { viewModel.pendingDestructiveAction = nil }
            } message: { pending in
                Text(dialogMessage(for: pending))
            }
        }
    }

    /// Only the row whose container matches the pending action presents the dialog, so it anchors
    /// to that row rather than every row trying to present the shared state.
    private var dialogPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDestructiveAction?.container.id == container.id },
            set: { presented in
                if !presented, viewModel.pendingDestructiveAction?.container.id == container.id {
                    viewModel.pendingDestructiveAction = nil
                }
            }
        )
    }

    private var dialogTitle: String {
        switch viewModel.pendingDestructiveAction?.action {
        case .stop: "Stop container?"
        case .restart: "Restart container?"
        case .kill: "Kill container?"
        case .delete: "Delete container?"
        case nil: ""
        }
    }

    private func confirmLabel(for action: DestructiveAction) -> String {
        switch action {
        case .stop: "Stop"
        case .restart: "Restart"
        case .kill: "Kill"
        case .delete: "Delete"
        }
    }

    private func dialogMessage(for pending: PendingContainerAction) -> String {
        let name = pending.container.displayName
        switch pending.action {
        case .stop: return "This stops \(name) gracefully."
        case .restart: return "This restarts \(name)."
        case .kill: return "This sends SIGKILL to \(name) immediately."
        case .delete: return "This removes \(name). It cannot be undone."
        }
    }
}

#Preview {
    List {
        // No previewable real data without a server; keep blank to avoid invented containers.
    }
}
