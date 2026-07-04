import SwiftUI

/// Body of the container detail. Pulled out of `ContainerDetailView` per swiftui-pro guidance to
/// avoid long view bodies broken up via `@ViewBuilder` properties.
struct ContainerDetailContent: View {
    @Environment(HostManager.self) private var hostManager
    let viewModel: ContainerDetailViewModel
    let detail: ContainerDetail
    let hostID: UUID

    var body: some View {
        List {
            ContainerDetailHeader(
                detail: detail,
                displayName: viewModel.displayName,
                serverName: serverName
            )
            ContainerDescriptionSection(hostID: hostID, containerID: viewModel.containerID)
            ContainerStatsSection(
                stats: viewModel.liveStats,
                cpuHistory: viewModel.cpuHistory,
                isRunning: detail.state.running
            )
            ContainerEnvironmentSection(environment: viewModel.environment)
            ContainerMountsSection(mounts: detail.mounts)
            ContainerNetworksSection(networkSettings: detail.networkSettings)
            ContainerLabelsSection(labels: detail.config.labels)
        }
        #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
    }

    private var serverName: String {
        hostManager.servers.first(where: { $0.id == viewModel.serverID })?.name ?? viewModel.serverID
    }
}
