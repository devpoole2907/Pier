import SwiftUI

/// One row in the deployments list. Shows name, a status badge (or in-progress spinner), image,
/// and an "update available" hint. Built as a small self-contained badge rather than reusing
/// `StatusBadgeView` (which is specialized to `ContainerStatus`/`ContainerActionState`) so this
/// surface doesn't need to touch shared container-status files.
struct DeploymentRowView: View {
    let deployment: Deployment
    let actionState: DeploymentActionState?

    init(deployment: Deployment, actionState: DeploymentActionState? = nil) {
        self.deployment = deployment
        self.actionState = actionState
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "shippingbox.fill")
                .imageScale(.large)
                .foregroundStyle(deployment.state.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(deployment.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let image = deployment.image, !image.isEmpty {
                    Text(image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if deployment.updateAvailable {
                    Label("Update available", systemImage: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.small)

            statusBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var badgeColor: Color {
        actionState?.color ?? deployment.state.color
    }

    private var badgeLabel: String {
        actionState?.displayName ?? deployment.state.label
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            if actionState != nil {
                ProgressView()
                    .controlSize(.small)
                    .tint(badgeColor)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
            }
            Text(badgeLabel)
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(badgeColor.opacity(0.15))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(badgeLabel)")
    }

    private var accessibilityLabel: String {
        var label = "\(deployment.name), \(actionState?.rowDetailText ?? deployment.state.label)"
        if let image = deployment.image, !image.isEmpty {
            label += ", image \(image)"
        }
        if deployment.updateAvailable {
            label += ", update available"
        }
        return label
    }
}

#Preview {
    List {
        // No previewable real data without a server; keep blank to avoid invented deployments.
    }
}
