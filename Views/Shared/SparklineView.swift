import SwiftUI
import Charts

/// Tiny line chart used in dashboard "top N" rows. Pulled out as its own view so each row's
/// chart has stable identity and the parent's body stays compact.
struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(
                x: .value("Sample", index),
                y: .value("Value", value)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

#Preview {
    SparklineView(values: [1, 4, 2, 8, 5, 9, 3, 7], color: .accentColor)
        .padding()
}
