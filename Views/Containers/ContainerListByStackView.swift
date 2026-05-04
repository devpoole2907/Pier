import SwiftUI

/// List grouped by compose stack. Containers without a stack go under "Standalone".
struct ContainerListByStackView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selection: Set<String>
    let isSelecting: Bool

    var body: some View {
        List(selection: $selection) {
            ForEach(viewModel.containersByStack, id: \.0) { stackName, containers in
                Section(stackName) {
                    ForEach(containers) { container in
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
