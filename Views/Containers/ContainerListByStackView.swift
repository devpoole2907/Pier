import SwiftUI

/// List grouped by compose stack. Containers without a stack go under "Standalone".
struct ContainerListByStackView: View {
    @Bindable var viewModel: ContainerListViewModel

    var body: some View {
        List {
            ForEach(viewModel.containersByStack, id: \.0) { stackName, containers in
                Section(stackName) {
                    ForEach(containers) { container in
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
