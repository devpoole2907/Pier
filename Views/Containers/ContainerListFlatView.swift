import SwiftUI

/// Flat list, sorted by status (running first), then alphabetically.
struct ContainerListFlatView: View {
    @Environment(HostManager.self) private var hostManager
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selection: Set<String>
    let isSelecting: Bool

    /// Show the per-row server only when the list spans all servers (no server scope selected) and
    /// there's more than one server — otherwise the server is already implied by the scope, and the
    /// "By server" grouping handles its own case.
    private var showsServer: Bool {
        hostManager.activeServerID == nil && hostManager.servers.count > 1
    }

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
        .softScrollEdges()
    }

    @ViewBuilder
    private func row(for container: Container) -> some View {
        SelectableContainerRow(
            container: container,
            viewModel: viewModel,
            isSelecting: isSelecting,
            serverName: showsServer ? serverName(for: container.serverID) : nil
        )
    }

    private func serverName(for serverID: String) -> String {
        hostManager.servers.first(where: { $0.id == serverID })?.name ?? serverID
    }
}
