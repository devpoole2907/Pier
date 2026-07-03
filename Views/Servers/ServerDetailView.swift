import SwiftUI

/// Full host detail for a single Komodo Server: state, live resource usage, per-disk breakdown and
/// network throughput. Stats are passed in from the dashboard's most recent poll; pulling to refresh
/// there updates them.
struct ServerDetailView: View {
    let server: KomodoServer
    let stats: ServerSystemStats?

    var body: some View {
        List {
            Section("Server") {
                LabeledContent("Status") {
                    Text(server.state.label)
                        .foregroundStyle(server.state.color)
                }
                if !server.region.isEmpty {
                    LabeledContent("Region", value: server.region)
                }
                if let ip = server.publicIP, !ip.isEmpty {
                    LabeledContent("Address", value: ip)
                }
                if let version = server.version, !version.isEmpty {
                    LabeledContent("Periphery", value: version)
                }
            }

            if let stats {
                Section("Resources") {
                    LabeledContent("CPU", value: percent(stats.cpuPercent))
                        .monospacedDigit()
                    LabeledContent("Memory") {
                        Text("\(gb(stats.memUsedGB)) / \(gb(stats.memTotalGB))  (\(percent(stats.memPercent)))")
                            .monospacedDigit()
                    }
                    LabeledContent("Load (1m / 5m / 15m)") {
                        Text("\(load(stats.loadOne)) / \(load(stats.loadFive)) / \(load(stats.loadFifteen))")
                            .monospacedDigit()
                    }
                }

                if !stats.disks.isEmpty {
                    Section("Disks") {
                        ForEach(stats.disks) { disk in
                            LabeledContent {
                                Text("\(gb(disk.usedGB)) / \(gb(disk.totalGB))  (\(percent(disk.usedPercent)))")
                                    .monospacedDigit()
                            } label: {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                                    Text(disk.mount)
                                    if !disk.fileSystem.isEmpty {
                                        Text(disk.fileSystem)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Network") {
                    LabeledContent("Ingress", value: bytes(stats.networkIngressBytes))
                        .monospacedDigit()
                    LabeledContent("Egress", value: bytes(stats.networkEgressBytes))
                        .monospacedDigit()
                }
            } else if server.state == .ok {
                Section {
                    LoadingView(message: "Loading stats…")
                }
            } else {
                Section {
                    Text("Host stats are unavailable while the server is \(server.state.label.lowercased()).")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(server.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func load(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2))) }
    private func gb(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(1)))) GB" }
    private func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }
}
