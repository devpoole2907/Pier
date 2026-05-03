import SwiftUI

/// One row in a dashboard top-N section. Shows name, value, and sparkline.
struct DashboardRowView: View {
    let row: DashboardRow
    let format: ValueFormat
    let color: Color

    enum ValueFormat {
        case percent
        case megabytes
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            SparklineView(values: row.history, color: color)
                .frame(width: 80)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.displayName), \(formattedValue)")
    }

    private var formattedValue: String {
        switch format {
        case .percent:
            (row.latestValue / 100).formatted(.percent.precision(.fractionLength(1)))
        case .megabytes:
            "\(row.latestValue.formatted(.number.precision(.fractionLength(0)))) MB"
        }
    }
}
