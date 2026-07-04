import SwiftUI

/// List grouped by Komodo server. Komodo's container list item doesn't expose a compose-project
/// name (unlike the old compose-stack label), so the previous "By stack" grouping is repurposed as
/// "By server" - the more natural grouping in Komodo's concept model, where a single Core
/// commonly manages several Servers.
struct ContainerListByServerView: View {
    @Environment(HostManager.self) private var hostManager
    @Bindable var viewModel: ContainerListViewModel
    @Binding var selection: Set<String>
    let isSelecting: Bool

    var body: some View {
        // See ContainerListFlatView: bind selection only while selecting to avoid taps leaking
        // into the selection set outside edit mode.
        List(selection: isSelecting ? $selection : .constant([])) {
            ForEach(viewModel.containersByServer, id: \.0) { serverID, containers in
                Section(serverName(for: serverID)) {
                    ForEach(containers) { container in
                        row(for: container)
                    }
                }
            }
        }
        .softScrollEdges()
    }

    private func serverName(for serverID: String) -> String {
        hostManager.servers.first(where: { $0.id == serverID })?.name ?? serverID
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
