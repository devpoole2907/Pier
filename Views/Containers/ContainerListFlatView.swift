import SwiftUI

/// Flat list, sorted by status (running first), then alphabetically.
struct ContainerListFlatView: View {
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selection: Set<String>
    let isSelecting: Bool

    var body: some View {
        // Only bind the selection set while actively selecting. Otherwise a plain tap on a
        // NavigationLink row can populate the set, leaving a phantom "1 selected" subtitle after
        // navigating back even though edit mode was never entered.
        List(selection: isSelecting ? $selection : .constant([])) {
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
        SelectableContainerRow(
            container: container,
            viewModel: viewModel,
            isSelecting: isSelecting
        )
    }
}
