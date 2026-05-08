import SwiftUI

/// Trailing swipe actions for container rows. Pulled out as its own view so list views stay tidy
/// and the same set is reused everywhere a container row appears.
struct ContainerSwipeActions: View {
    let container: Container
    let viewModel: ContainerListViewModel

    var body: some View {
        if let actionState = viewModel.actionState(for: container) {
            Button(actionState.displayName, systemImage: actionState.symbolName) {}
                .tint(actionState.color)
                .disabled(true)
        } else if container.state == .running {
            Button("Stop", systemImage: "stop.fill") {
                viewModel.stop(container)
            }
            .tint(.orange)
            Button("Restart", systemImage: "arrow.clockwise") {
                viewModel.restart(container)
            }
            .tint(.blue)
        } else {
            Button("Start", systemImage: "play.fill") {
                Task { await viewModel.start(container) }
            }
            .tint(.green)
        }
    }
}
