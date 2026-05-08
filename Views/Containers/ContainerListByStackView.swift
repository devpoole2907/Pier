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
        SelectableContainerRow(
            container: container,
            viewModel: viewModel,
            isSelecting: isSelecting
        )
    }
}
