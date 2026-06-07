import SwiftUI

struct ProxyHostRowView: View {
    let host: NPMProxyHost
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(host.domain_names.joined(separator: ", "))
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text("\(host.forward_scheme ?? "http")://\(host.forward_host):\(String(host.forward_port))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let cert = host.certificate {
                    Text(cert.nice_name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            statusBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let actionState {
            actionBadge(state: actionState)
        } else if host.enabled?.boolValue ?? true {
            enabledBadge
        } else {
            disabledBadge
        }
    }

    private var enabledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.small)
            Text("Enabled")
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(.green)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(.green.opacity(0.15))
        }
    }

    private var disabledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "stop.circle.fill")
                .imageScale(.small)
            Text("Disabled")
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(.secondary.opacity(0.15))
        }
    }

    private func actionBadge(state: NPMActionState) -> some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
                .tint(state.color)
            Text(state.displayName)
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(state.color)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(state.color.opacity(0.15))
        }
    }
}
