import SwiftUI

/// Aggregate stats dashboard. Shows total CPU/RAM and top 5 containers by each.
struct StatsDashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(client: PortainerClient, endpointID: Int) {
        _viewModel = State(initialValue: DashboardViewModel(client: client, endpointID: endpointID))
    }

    var body: some View {
        List {
            Section("Totals") {
                LabeledContent("CPU") {
                    Text(viewModel.totalCPUPercent / 100, format: .percent.precision(.fractionLength(1)))
                        .monospacedDigit()
                }
                LabeledContent("Memory") {
                    Text(viewModel.totalMemoryUsedBytes.byteCountString)
                        .monospacedDigit()
                }
            }

            Section("Top by CPU") {
                if viewModel.topByCPU.isEmpty {
                    Text("Waiting for stats…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.topByCPU) { row in
                        DashboardRowView(row: row, format: .percent, color: .blue)
                    }
                }
            }

            Section("Top by memory") {
                if viewModel.topByMemory.isEmpty {
                    Text("Waiting for stats…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.topByMemory) { row in
                        DashboardRowView(row: row, format: .megabytes, color: .purple)
                    }
                }
            }

            if let error = viewModel.loadError {
                Section {
                    Text(error.errorDescription ?? "Unknown error")
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { Task { await viewModel.start() } }
        .onDisappear { viewModel.stop() }
    }
}
