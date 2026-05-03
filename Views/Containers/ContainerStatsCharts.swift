import SwiftUI
import Charts

/// CPU and memory line charts for the container detail screen.
struct ContainerStatsCharts: View {
    let samples: [ContainerStats]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            Text("CPU %")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart(samples) { sample in
                LineMark(
                    x: .value("Time", sample.read),
                    y: .value("CPU", sample.cpuPercent)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...max(100, samples.map(\.cpuPercent).max() ?? 100))
            .frame(height: 80)

            Text("Memory MB")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.read),
                    y: .value("Memory", Double(sample.memoryUsageBytes) / 1_048_576)
                )
                .foregroundStyle(.purple.opacity(0.4))
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", sample.read),
                    y: .value("Memory", Double(sample.memoryUsageBytes) / 1_048_576)
                )
                .foregroundStyle(.purple)
                .interpolationMethod(.monotone)
            }
            .frame(height: 80)
        }
    }
}
