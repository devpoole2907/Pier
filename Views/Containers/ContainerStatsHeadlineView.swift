import SwiftUI

/// Big numbers row showing CPU%, memory used / limit, and total RX/TX.
struct ContainerStatsHeadlineView: View {
    let latest: ContainerStats

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            LabeledContent("CPU") {
                Text(latest.cpuPercent / 100, format: .percent.precision(.fractionLength(1)))
                    .monospacedDigit()
            }
            LabeledContent("Memory") {
                Text("\(latest.memoryUsageBytes.byteCountString) / \(latest.memoryLimitBytes.byteCountString)")
                    .monospacedDigit()
            }
            LabeledContent("Network RX") {
                Text(latest.networkRxBytes.byteCountString)
                    .monospacedDigit()
            }
            LabeledContent("Network TX") {
                Text(latest.networkTxBytes.byteCountString)
                    .monospacedDigit()
            }
        }
    }
}
