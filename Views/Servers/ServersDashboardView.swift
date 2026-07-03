import SwiftUI

/// Resolves the active host then renders the Servers dashboard. Surfaced as a destination within
/// the More tab (see `MoreTab`).
struct ServersContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            ServersDashboardView(client: client)
                .id(host.id)
        }
    }
}

/// The Komodo-native home for host monitoring: every Server the Core manages, with live CPU,
/// memory, load and disk usage. Tapping a server opens its full host detail.
struct ServersDashboardView: View {
    @State private var viewModel: ServersDashboardViewModel

    init(client: KomodoClient) {
        _viewModel = State(initialValue: ServersDashboardViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.servers.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading servers…")
            } else if let error = viewModel.loadError, viewModel.servers.isEmpty {
                ErrorView(error: error, retry: { Task { await viewModel.load() } })
            } else if viewModel.servers.isEmpty {
                EmptyStateView(
                    title: "No servers",
                    systemImage: "server.rack",
                    message: "Servers connected to this Komodo Core will appear here."
                )
            } else {
                List {
                    ForEach(viewModel.servers) { server in
                        NavigationLink(value: server) {
                            ServerRowView(server: server, stats: viewModel.stats(for: server))
                        }
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationDestination(for: KomodoServer.self) { server in
            ServerDetailView(server: server, stats: viewModel.stats(for: server))
        }
    }
}

/// One server in the dashboard: name, health state, and a compact live-metrics strip.
struct ServerRowView: View {
    let server: KomodoServer
    let stats: ServerSystemStats?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(server.name)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .imageScale(.small)
                    Text(server.state.label)
                }
                .font(.caption)
                .foregroundStyle(server.state.color)
            }

            if let stats {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xLarge) {
                    ServerMetric(title: "CPU", value: percent(stats.cpuPercent))
                    ServerMetric(title: "MEM", value: percent(stats.memPercent))
                    if let disk = busiestDisk(stats) {
                        ServerMetric(title: "DISK", value: percent(disk.usedPercent))
                    }
                    ServerMetric(title: "LOAD", value: stats.loadOne.formatted(.number.precision(.fractionLength(2))))
                }
                .font(.subheadline)
            } else if server.state == .ok {
                Text("Loading stats…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
    }

    private func busiestDisk(_ stats: ServerSystemStats) -> DiskStat? {
        stats.disks.max { $0.usedPercent < $1.usedPercent }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

/// A labelled metric value used across the servers dashboard and detail.
struct ServerMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }
}
