import SwiftUI

/// Live-stats section embedded in the container detail. Komodo carries a stats snapshot directly
/// on each container list item rather than exposing a per-container stats stream (unlike the old
/// Docker-management backend this replaced), so this section is purely presentational: it's fed by
/// `ContainerDetailViewModel.liveStats` / `.cpuHistory`, which the detail view keeps fresh via
/// `runStatsPolling(every:)` on its own polling loop (re-listing containers on this container's
/// server), not a socket/stream owned by this view.
struct ContainerStatsSection: View {
    let stats: ContainerLiveStats?
    let cpuHistory: [Double]
    let isRunning: Bool

    var body: some View {
        Section("Live stats") {
            if !isRunning {
                ContentUnavailableView(
                    "Container is not running",
                    systemImage: "stop.circle",
                    description: Text("Stats are only available for running containers.")
                )
            } else if let stats {
                ContainerStatsTilesView(stats: stats)
                if cpuHistory.count > 1 {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                        Text("CPU history")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SparklineView(values: cpuHistory, color: DesignSystem.Colors.accent)
                    }
                }
            } else {
                HStack {
                    ProgressView()
                    Text("Loading stats…")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
