import SwiftUI

struct RedirectionHostRowView: View {
    let host: NPMRedirectionHost
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(host.domain_names.joined(separator: ", "))
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\u{2192} \(host.forward_domain_name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("HTTP \(host.forward_http_code)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
