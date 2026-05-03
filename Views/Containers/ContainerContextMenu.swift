import SwiftUI

/// Long-press context menu for container rows. Mirrors the swipe actions and adds a delete option.
struct ContainerContextMenu: View {
    let container: Container
    let viewModel: ContainerListViewModel

    var body: some View {
        if container.state == .running {
            Button("Stop", systemImage: "stop.fill") {
                Task { await viewModel.stop(container) }
            }
            Button("Restart", systemImage: "arrow.clockwise") {
                Task { await viewModel.restart(container) }
            }
            Button("Kill", systemImage: "bolt.slash.fill", role: .destructive) {
                Task { await viewModel.kill(container) }
            }
        } else {
            Button("Start", systemImage: "play.fill") {
                Task { await viewModel.start(container) }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await viewModel.delete(container) }
            }
        }
    }
}
