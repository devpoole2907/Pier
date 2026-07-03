import SwiftUI

/// Top-level list of Komodo deployments (single-container resources attached to a Server).
/// `listDeployments()` returns deployments across every server on the active host, so this view
/// filters client-side by `HostManager.activeServerID` - `nil` means "All servers", matching the
/// title-menu server picker `MoreTab` attaches via `.serverScopeMenu()`.
struct DeploymentsListView: View {
    @Environment(HostManager.self) private var hostManager
    @State private var viewModel: DeploymentsViewModel

    init(client: KomodoClient) {
        _viewModel = State(initialValue: DeploymentsViewModel(client: client))
    }

    var body: some View {
        Group {
            if viewModel.deployments.isEmpty, viewModel.isLoading {
                LoadingView(message: "Loading deployments…")
            } else if let error = viewModel.loadError, viewModel.deployments.isEmpty {
                ErrorView(error: error, retry: {
                    Task { await viewModel.load() }
                })
            } else if viewModel.deployments.isEmpty {
                EmptyStateView(
                    title: "No deployments",
                    systemImage: "shippingbox",
                    message: "Single-container deployments managed by Komodo will appear here."
                )
            } else if visibleDeployments.isEmpty {
                EmptyStateView(
                    title: "No deployments",
                    systemImage: "shippingbox",
                    message: "No deployments on this server."
                )
            } else {
                List {
                    ForEach(visibleDeployments) { deployment in
                        row(for: deployment)
                    }
                }
            }
        }
        .navigationDestination(for: Deployment.self) { deployment in
            DeploymentDetailView(deployment: deployment, viewModel: viewModel)
        }
        .alert(item: $viewModel.pendingDestructiveAction, content: destroyAlert)
        .navigationSubtitle(navigationSubtitleText)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var visibleDeployments: [Deployment] {
        guard let activeServerID = hostManager.activeServerID else { return viewModel.deployments }
        return viewModel.deployments.filter { $0.serverID == activeServerID }
    }

    private var navigationSubtitleText: String {
        guard let activeServerID = hostManager.activeServerID else { return "" }
        return hostManager.servers.first(where: { $0.id == activeServerID })?.name ?? ""
    }

    @ViewBuilder
    private func row(for deployment: Deployment) -> some View {
        let actionState = viewModel.actionState(for: deployment)
        NavigationLink(value: deployment) {
            DeploymentRowView(deployment: deployment, actionState: actionState)
        }
        .disabled(actionState != nil)
        .swipeActions(edge: .trailing) {
            swipeActions(for: deployment, actionState: actionState)
        }
        .contextMenu {
            contextMenuActions(for: deployment, actionState: actionState)
        }
    }

    @ViewBuilder
    private func swipeActions(for deployment: Deployment, actionState: DeploymentActionState?) -> some View {
        if let actionState {
            Button(actionState.displayName, systemImage: "hourglass") { }
                .tint(actionState.color)
                .disabled(true)
        } else if deployment.isActive {
            Button("Stop", systemImage: "stop.fill") {
                Task { await viewModel.stop(deployment) }
            }
            .tint(.orange)
            Button("Restart", systemImage: "arrow.clockwise") {
                Task { await viewModel.restart(deployment) }
            }
            .tint(.blue)
        } else {
            Button("Start", systemImage: "play.fill") {
                Task { await viewModel.start(deployment) }
            }
            .tint(.green)
        }
    }

    @ViewBuilder
    private func contextMenuActions(for deployment: Deployment, actionState: DeploymentActionState?) -> some View {
        if let actionState {
            Button(actionState.displayName, systemImage: "hourglass") { }
                .disabled(true)
        } else {
            Button("Deploy", systemImage: "square.and.arrow.down.on.square") {
                Task { await viewModel.deploy(deployment) }
            }
            Button("Pull image", systemImage: "arrow.down.circle") {
                Task { await viewModel.pull(deployment) }
            }
            Button("Start", systemImage: "play.fill") {
                Task { await viewModel.start(deployment) }
            }
            .disabled(deployment.isActive)
            Button("Stop", systemImage: "stop.fill") {
                Task { await viewModel.stop(deployment) }
            }
            .disabled(!deployment.isActive)
            Button("Restart", systemImage: "arrow.clockwise") {
                Task { await viewModel.restart(deployment) }
            }
            Button("Pause", systemImage: "pause.fill") {
                Task { await viewModel.pause(deployment) }
            }
            Button("Unpause", systemImage: "play.circle") {
                Task { await viewModel.unpause(deployment) }
            }
            Button("Destroy", systemImage: "trash", role: .destructive) {
                viewModel.requestDestroy(deployment)
            }
        }
    }

    private func destroyAlert(for pending: PendingDeploymentAction) -> Alert {
        Alert(
            title: Text("Destroy deployment?"),
            message: Text("This removes \(pending.deployment.name) and its container. This action cannot be undone."),
            primaryButton: .destructive(Text("Destroy")) {
                Task { await viewModel.confirmDestructiveAction() }
            },
            secondaryButton: .cancel {
                viewModel.pendingDestructiveAction = nil
            }
        )
    }
}
