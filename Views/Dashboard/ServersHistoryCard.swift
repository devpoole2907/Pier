import SwiftUI
import Charts

/// CPU% and memory% over time for every reachable server, from `KomodoClient.historicalStats`.
/// Two single-axis charts (never one dual-axis chart for two different measures) stacked in one
/// card. With a single reachable server each chart is one plain line with a soft area wash and no
/// legend box (there's only one thing it could be); with several servers each gets a fixed,
/// stable color from `DashboardPalette` and a shared legend identifies them.
struct ServersHistoryCard: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
            Text("History")
                .font(.headline)

            if orderedServerIDs.isEmpty {
                Text("No historical data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignSystem.Spacing.large)
            } else {
                MetricHistoryChart(
                    title: "CPU",
                    unit: "%",
                    points: cpuPoints,
                    orderedServerNames: orderedServerNames
                )
                MetricHistoryChart(
                    title: "Memory",
                    unit: "%",
                    points: memoryPoints,
                    orderedServerNames: orderedServerNames
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    /// Servers with at least one history sample, in a stable (name) order - this order both
    /// drives legend ordering and is fed to `DashboardPalette` so a server's color is stable
    /// across refreshes.
    private var orderedServerIDs: [String] {
        viewModel.reachableServers
            .filter { !viewModel.history(for: $0).isEmpty }
            .sorted { $0.name < $1.name }
            .map(\.id)
    }

    private var orderedServerNames: [String] {
        let servers = viewModel.reachableServers
        return orderedServerIDs.compactMap { id in servers.first(where: { $0.id == id })?.name }
    }

    private var cpuPoints: [HistoryPoint] {
        points { $0.cpuPercent }
    }

    private var memoryPoints: [HistoryPoint] {
        points { sample in
            guard sample.memTotalGB > 0 else { return 0 }
            return (sample.memUsedGB / sample.memTotalGB) * 100
        }
    }

    private func points(_ value: (SystemStatsSample) -> Double) -> [HistoryPoint] {
        let servers = viewModel.reachableServers
        return orderedServerIDs.flatMap { id -> [HistoryPoint] in
            guard let server = servers.first(where: { $0.id == id }) else { return [] }
            return viewModel.history(for: server).map { sample in
                HistoryPoint(serverID: id, serverName: server.name, ts: sample.ts, value: value(sample))
            }
        }
    }
}

private struct HistoryPoint: Identifiable {
    let id = UUID()
    let serverID: String
    let serverName: String
    let ts: Date
    let value: Double
}

/// One single-axis time-series chart for a metric, shared by CPU and memory.
private struct MetricHistoryChart: View {
    let title: String
    let unit: String
    let points: [HistoryPoint]
    let orderedServerNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            Text("\(title) (\(unit))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.ts),
                    y: .value(title, point.value)
                )
                .foregroundStyle(by: .value("Server", point.serverName))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if isSingleSeries {
                    AreaMark(
                        x: .value("Time", point.ts),
                        y: .value(title, point.value)
                    )
                    .foregroundStyle(seriesColor(for: point.serverName).opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale(
                domain: orderedServerNames,
                range: orderedServerNames.enumerated().map { index, _ in
                    DashboardPalette.series[index % DashboardPalette.series.count]
                }
            )
            .chartLegend(isSingleSeries ? .hidden : .visible)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text("\(Int(percent))%")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day().hour())
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 160)
        }
    }

    private var isSingleSeries: Bool {
        orderedServerNames.count <= 1
    }

    private func seriesColor(for serverName: String) -> Color {
        guard let index = orderedServerNames.firstIndex(of: serverName) else {
            return DashboardPalette.series[0]
        }
        return DashboardPalette.series[index % DashboardPalette.series.count]
    }
}
