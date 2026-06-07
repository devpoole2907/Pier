import SwiftUI

struct AccessListRowView: View {
    let list: NPMAccessList
    let actionState: NPMActionState?

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(list.name)
                    .font(.body)
                    .fontWeight(.medium)
                if let count = list.proxy_host_count {
                    Text("\(count) host\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(authSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            if let actionState {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small).tint(actionState.color)
                    Text(actionState.displayName).font(.caption).fontDesign(.rounded)
                }
                .foregroundStyle(actionState.color)
                .padding(.horizontal, DesignSystem.Spacing.small)
                .padding(.vertical, DesignSystem.Spacing.tight)
                .background { Capsule().fill(actionState.color.opacity(0.15)) }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
    }

    private var authSummary: String {
        var parts: [String] = []
        if let items = list.items, !items.isEmpty {
            parts.append("\(items.count) user\(items.count == 1 ? "" : "s")")
        }
        if let clients = list.clients, !clients.isEmpty {
            parts.append("\(clients.count) rule\(clients.count == 1 ? "" : "s")")
        }
        if list.satisfy_any?.boolValue ?? false {
            parts.append("any")
        }
        return parts.isEmpty ? "" : parts.joined(separator: ", ")
    }
}
