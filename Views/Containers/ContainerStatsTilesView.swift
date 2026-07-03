import SwiftUI

/// Stat tiles for a container's inline live-stats snapshot: CPU%, memory usage/%, network I/O,
/// block I/O, and process count. All values are Komodo's pre-formatted display strings - see
/// `ContainerLiveStats`, which parses numeric doubles out separately only for sorting/gauges.
struct ContainerStatsTilesView: View {
    let stats: ContainerLiveStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            LabeledContent("CPU", value: display(stats.cpuPercRaw))
                .monospacedDigit()
            LabeledContent("Memory") {
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.tight) {
                    Text(display(stats.memUsage))
                    if !stats.memPercRaw.isEmpty {
                        Text(stats.memPercRaw)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .monospacedDigit()
            LabeledContent("Network I/O", value: display(stats.netIO))
                .monospacedDigit()
            LabeledContent("Block I/O", value: display(stats.blockIO))
                .monospacedDigit()
            LabeledContent("PIDs", value: display(stats.pids))
                .monospacedDigit()
        }
    }

    private func display(_ raw: String) -> String {
        raw.isEmpty ? "–" : raw
    }
}
