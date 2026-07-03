import SwiftUI

/// Deployment detail - summary plus the full set of lifecycle actions. Shares the list's
/// `DeploymentsViewModel` instance so action-in-progress state stays in sync when navigating back.
struct DeploymentDetailView: View {
    let deployment: Deployment
    let viewModel: DeploymentsViewModel

    @State private var pendingStop = false
    @State private var pendingDestroy = false

    var body: some View {
        List {
            Section("Deployment") {
                LabeledContent("Status") {
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }
                if let image = deployment.image, !image.isEmpty {
                    LabeledContent("Image") {
                        Text(image)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if deployment.updateAvailable {
                    LabeledContent("Update") {
                        Text("Available")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(deployment.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .alert("Stop deployment?", isPresented: $pendingStop) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task { await viewModel.stop(deployment) }
            }
        } message: {
            Text("This stops \(deployment.name)'s container.")
        }
        .alert("Destroy deployment?", isPresented: $pendingDestroy) {
            Button("Cancel", role: .cancel) { }
            Button("Destroy", role: .destructive) {
                Task { await viewModel.destroy(deployment) }
            }
        } message: {
            Text("This removes \(deployment.name) and its container. This action cannot be undone.")
        }
    }

    private var currentActionState: DeploymentActionState? {
        viewModel.actionState(for: deployment)
    }

    private var statusText: String {
        currentActionState?.rowDetailText ?? deployment.state.label
    }

    private var statusColor: Color {
        currentActionState?.color ?? deployment.state.color
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .platformTrailing) {
            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Deploy", systemImage: "square.and.arrow.down.on.square") {
                    Task { await viewModel.deploy(deployment) }
                }
                Button("Pull image", systemImage: "arrow.down.circle") {
                    Task { await viewModel.pull(deployment) }
                }

                Divider()

                Button("Start", systemImage: "play.fill") {
                    Task { await viewModel.start(deployment) }
                }
                .disabled(deployment.isActive)
                Button("Stop", systemImage: "stop.fill") {
                    pendingStop = true
                }
                .disabled(!deployment.isActive)
                Button("Restart", systemImage: "arrow.clockwise") {
                    Task { await viewModel.restart(deployment) }
                }

                Divider()

                Button("Pause", systemImage: "pause.fill") {
                    Task { await viewModel.pause(deployment) }
                }
                Button("Unpause", systemImage: "play.circle") {
                    Task { await viewModel.unpause(deployment) }
                }

                Divider()

                Button("Destroy", systemImage: "trash", role: .destructive) {
                    pendingDestroy = true
                }
            }
            .disabled(currentActionState != nil)
        }
    }
}
