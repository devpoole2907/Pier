import SwiftUI

/// Flat list, sorted by status (running first), then alphabetically.
struct ContainerListFlatView: View {
    @Bindable var viewModel: ContainerListViewModel

    var body: some View {
        List {
            let visible = viewModel.visibleContainers
            let running = visible.filter { $0.state == .running }
            let other = visible.filter { $0.state != .running }

            if !running.isEmpty {
                Section("Running") {
                    ForEach(running) { container in
                        NavigationLink(value: ContainerNavigationValue(containerID: container.id, displayName: container.displayName)) {
                            ContainerRowView(container: container)
                        }
                        .swipeActions(edge: .trailing) {
                            ContainerSwipeActions(container: container, viewModel: viewModel)
                        }
                        .contextMenu { ContainerContextMenu(container: container, viewModel: viewModel) }
                    }
                }
            }

            if !other.isEmpty {
                Section("Stopped") {
                    ForEach(other) { container in
                        NavigationLink(value: ContainerNavigationValue(containerID: container.id, displayName: container.displayName)) {
                            ContainerRowView(container: container)
                        }
                        .swipeActions(edge: .trailing) {
                            ContainerSwipeActions(container: container, viewModel: viewModel)
                        }
                        .contextMenu { ContainerContextMenu(container: container, viewModel: viewModel) }
                    }
                }
            }
        }
    }
}
