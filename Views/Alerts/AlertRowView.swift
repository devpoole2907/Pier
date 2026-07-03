import SwiftUI

/// One row in the alerts list: level badge, summary, target type, and a relative timestamp.
struct AlertRowView: View {
    let alert: KomodoAlert

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(alert.summary)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: DesignSystem.Spacing.small) {
                    if !alert.targetType.isEmpty {
                        Label(alert.targetType, systemImage: "server.rack")
                    }
                    Text(timestampText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            levelBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.level.label): \(alert.summary), \(timestampText)")
    }

    private var timestampText: String {
        if alert.resolved, let resolvedTS = alert.resolvedTS {
            "Resolved \(resolvedTS.relativeShort)"
        } else {
            alert.ts.relativeShort
        }
    }

    private var levelBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .imageScale(.small)
            Text(alert.level.label)
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(alert.level.color)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(alert.level.color.opacity(0.15))
        }
    }

    private var symbolName: String {
        switch alert.level {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}
