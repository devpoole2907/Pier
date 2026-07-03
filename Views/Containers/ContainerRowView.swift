import SwiftUI

/// One row in the container list. Shows name, status, image, and uptime/since.
struct ContainerRowView: View {
    let container: Container
    let actionState: ContainerActionState?

    init(container: Container, actionState: ContainerActionState? = nil) {
        self.container = container
        self.actionState = actionState
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

    var body: some View {
        let actionState = viewModel.actionState(for: container)
        if isSelecting {
            ContainerRowView(container: container, actionState: actionState)
                .tag(container.id)
        } else {
            NavigationLink(value: ContainerNavigationValue(containerID: container.id, serverID: container.serverID, displayName: container.displayName)) {
                ContainerRowView(container: container, actionState: actionState)
            }
            .tag(container.id)
            .disabled(actionState != nil)
            .swipeActions(edge: .trailing) {
                ContainerSwipeActions(container: container, viewModel: viewModel)
            }
            .contextMenu {
                ContainerContextMenu(container: container, viewModel: viewModel)
            }
        }
    }
}

#Preview {
    List {
        // No previewable real data without a server; keep blank to avoid invented containers.
    }
}
