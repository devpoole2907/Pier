import SwiftUI

/// At-a-glance server counts plus aggregate live CPU/memory across every reachable server. The
/// top-level "how healthy is everything right now" card - `ServersHistoryCard` covers the
/// over-time view.
struct ServersSummaryCard: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            HStack(spacing: DesignSystem.Spacing.xLarge) {
                StatTile(title: "Total", value: "\(viewModel.servers.count)")
                StatTile(title: "Healthy", value: "\(viewModel.healthyCount)", tint: .green)
                if viewModel.unreachableCount > 0 {
                    StatTile(title: "Unreachable", value: "\(viewModel.unreachableCount)", tint: .red)
                }
            }

            if viewModel.healthyCount > 0 {
                Divider()
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xLarge) {
                    MetricMeter(title: "Avg CPU", percent: viewModel.averageCPUPercent)
                    MetricMeter(title: "Avg Memory", percent: viewModel.averageMemoryPercent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }
}

/// A single label/value stat, per the app's stat-tile convention: sentence-case label, no
/// trailing colon, value in the default proportional figure style.
private struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}

/// A compact horizontal meter for an aggregate percentage. Fill color carries severity (matching
/// how `ServerState.color` already signals health elsewhere): green under 70%, orange into
/// caution, red once a resource is nearly exhausted. Shows "—" when no reachable server has
/// reported stats yet, rather than a misleading 0%.
private struct MetricMeter: View {
    let title: String
    let percent: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(severityColor)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(severityColor)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(percent.map { "\(Int($0.rounded())) percent" } ?? "No data")
    }

    private var fraction: Double {
        guard let percent else { return 0 }
        return min(max(percent / 100, 0), 1)
    }

    private var severityColor: Color {
        guard let percent else { return .secondary }
        switch percent {
        case ..<70: return .green
        case ..<90: return .orange
        default: return .red
        }
    }
}
