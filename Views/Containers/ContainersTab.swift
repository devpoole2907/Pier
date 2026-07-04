import SwiftUI
import SwiftData

/// Container tab root. Owns a single `NavigationStack` so the navigation hierarchy is owned by
/// the tab itself - this means deep-linking to a container detail won't pop the stack when the
/// user switches tabs.
struct ContainersTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ContainerListContainer()
                .navigationTitle("Containers")
                #if os(iOS)
                .toolbarTitleDisplayMode(.inlineLarge)
                #endif
                .hostTitleMenu()
                .serverScopeMenu()
                .navigationDestination(for: ContainerNavigationValue.self) { value in
                    ContainerDetailContainer(navigationValue: value)
                }
        }
    }
}

/// The pair of values needed to push the detail screen. Identifiable for use with sheets, too.
struct ContainerNavigationValue: Hashable, Identifiable {
    let containerID: String
    let serverID: String
    let displayName: String

    var id: String { containerID }
}
