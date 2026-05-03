import SwiftUI
import Charts

/// Live stats section embedded in the container detail. Owns its own `StatsViewModel` so it can
/// stop the stream when the parent view goes off-screen.
struct ContainerStatsSection: View {
    let isRunning: Bool
    @State private var viewModel: StatsViewModel

    init(client: PortainerClient, endpointID: Int, containerID: String, isRunning: Bool) {
        self.isRunning = isRunning
        _viewModel = State(initialValue: StatsViewModel(
            client: client,
            endpointID: endpointID,
            containerID: containerID
        ))
    }

    var body: some View {
        Section("Live stats") {
            if !isRunning {
                ContentUnavailableView(
                    "Container is not running",
                    systemImage: "stop.circle",
                    description: Text("Stats are only available for running containers.")
                )
            } else if let latest = viewModel.latest {
                ContainerStatsHeadlineView(latest: latest)
                ContainerStatsCharts(samples: viewModel.samples)
            } else if let error = viewModel.streamError {
                Text(error.errorDescription ?? "Stream failed")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else {
                HStack {
                    ProgressView()
                    Text("Connecting…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if isRunning {
                Task { await viewModel.start() }
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}
