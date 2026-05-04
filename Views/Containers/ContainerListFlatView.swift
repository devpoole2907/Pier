import SwiftUI

/// Flat list, sorted by status (running first), then alphabetically.
struct ContainerListFlatView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selection: Set<String>
    let isSelecting: Bool

    var body: some View {
        List(selection: $selection) {
            let visible = viewModel.visibleContainers
            let running = visible.filter { $0.state == .running }
            let other = visible.filter { $0.state != .running }

            if !running.isEmpty {
                Section("Running") {
                    ForEach(running) { container in
                        row(for: container)
                    }
                }
            }

            if !other.isEmpty {
                Section("Stopped") {
                    ForEach(other) { container in
                        row(for: container)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for container: Container) -> some View {
        if isSelecting {
            ContainerRowView(container: container)
                .tag(container.id)
        } else {
            NavigationLink(value: ContainerNavigationValue(containerID: container.id, displayName: container.displayName)) {
                ContainerRowView(container: container)
            }
            .tag(container.id)
            .swipeActions(edge: .trailing) {
                ContainerSwipeActions(container: container, viewModel: viewModel)
            }
            .contextMenu { ContainerContextMenu(container: container, viewModel: viewModel) }
        }
    }
}
