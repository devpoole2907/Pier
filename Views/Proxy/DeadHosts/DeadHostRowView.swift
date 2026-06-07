import SwiftUI

struct DeadHostRowView: View {
    let host: NPMDeadHost
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(host.domain_names.joined(separator: ", "))
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("Returns 404 for unknown hosts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            statusBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let actionState {
            HStack(spacing: 4) {
                ProgressView().controlSize(.small).tint(actionState.color)
                Text(actionState.displayName).font(.caption).fontDesign(.rounded)
            }
            .foregroundStyle(actionState.color)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background { Capsule().fill(actionState.color.opacity(0.15)) }
        } else if host.enabled?.boolValue ?? true {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").imageScale(.small)
                Text("Enabled").font(.caption).fontDesign(.rounded)
            }
            .foregroundStyle(.green)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background { Capsule().fill(.green.opacity(0.15)) }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "stop.circle.fill").imageScale(.small)
                Text("Disabled").font(.caption).fontDesign(.rounded)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background { Capsule().fill(.secondary.opacity(0.15)) }
        }
    }
}
