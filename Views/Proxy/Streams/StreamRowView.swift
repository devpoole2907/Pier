import SwiftUI

struct StreamRowView: View {
    let stream: NPMStream
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text("Port \(String(stream.incoming_port))")
                    .font(.body)
                    .fontWeight(.medium)
                Text("\u{2192} \(stream.forwarding_host):\(String(stream.forwarding_port))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if stream.tcp_forwarding?.boolValue ?? false {
                        Text("TCP").font(.caption2).foregroundStyle(.blue)
                    }
                    if stream.udp_forwarding?.boolValue ?? false {
                        Text("UDP").font(.caption2).foregroundStyle(.purple)
                    }
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
            HStack(spacing: 4) {
                ProgressView().controlSize(.small).tint(actionState.color)
                Text(actionState.displayName).font(.caption).fontDesign(.rounded)
            }
            .foregroundStyle(actionState.color)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background { Capsule().fill(actionState.color.opacity(0.15)) }
        } else if stream.enabled?.boolValue ?? true {
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
