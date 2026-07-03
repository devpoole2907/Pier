import SwiftUI

/// One row in the procedures list: name, stage count, last/next run dates, and a state badge
/// (or a progress badge while a run is in flight).
struct ProcedureRowView: View {
    let procedure: Procedure
    let isRunning: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(procedure.name)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: DesignSystem.Spacing.small) {
                    Label("\(procedure.stages) stage\(procedure.stages == 1 ? "" : "s")", systemImage: "square.stack.3d.up")
                    if let lastRunAt = procedure.lastRunAt {
                        Text("Last run \(lastRunAt.relativeShort)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let nextScheduledRun = procedure.nextScheduledRun {
                    Label("Next run \(nextScheduledRun.relativeShort)", systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            stateBadge
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateBadge: some View {
        if isRunning {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.blue)
                Text("Running")
                    .font(.caption)
                    .fontDesign(.rounded)
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background {
                Capsule().fill(Color.blue.opacity(0.15))
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: symbolName)
                    .imageScale(.small)
                Text(procedure.state)
                    .font(.caption)
                    .fontDesign(.rounded)
            }
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.tight)
            .background {
                Capsule().fill(color.opacity(0.15))
            }
        }
    }

    private var normalizedState: String {
        procedure.state.lowercased()
    }

    private var color: Color {
        switch normalizedState {
        case "ok", "complete", "completed", "success": .green
        case "running": .blue
        case "failed", "error": .red
        default: .secondary
        }
    }

    private var symbolName: String {
        switch normalizedState {
        case "ok", "complete", "completed", "success": "checkmark.circle.fill"
        case "running": "arrow.triangle.2.circlepath.circle.fill"
        case "failed", "error": "xmark.octagon.fill"
        default: "questionmark.circle.fill"
        }
    }
}
