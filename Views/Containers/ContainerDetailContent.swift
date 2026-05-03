import SwiftUI

/// Body of the container detail. Pulled out of `ContainerDetailView` per swiftui-pro guidance to
/// avoid long view bodies broken up via `@ViewBuilder` properties.
struct ContainerDetailContent: View {
    let viewModel: ContainerDetailViewModel
    let detail: ContainerDetail

    var body: some View {
        List {
            ContainerDetailHeader(detail: detail, displayName: viewModel.displayName)
            ContainerStatsSection(
                client: viewModel.portainerClient,
                endpointID: viewModel.resolvedEndpointID,
                containerID: viewModel.containerID,
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
}
