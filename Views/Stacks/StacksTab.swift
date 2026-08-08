import SwiftUI
import SwiftData

/// Stacks tab root with its own NavigationStack.
struct StacksTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            StacksContainer()
                .navigationTitle("Stacks")
                #if os(iOS)
                .toolbarTitleDisplayMode(.inlineLarge)
                #endif
                .navigationDestination(for: Stack.self) { stack in
                    StackDetailContainer(stack: stack)
                }
                .navigationDestination(for: ContainerNavigationValue.self) { value in
                    ContainerDetailContainer(navigationValue: value)
                }
        }
    }
}

/// Resolves the active host and presents the stacks list, or a no-host placeholder.
struct StacksContainer: View {
    var body: some View {
        ActiveHostGate { host, client in
            StacksListView(client: client)
                .id(host.id)
        }
    }
}

/// Resolves the host and presents the stack detail.
struct StackDetailContainer: View {
    let stack: Stack

    var body: some View {
        ActiveHostGate { _, client in
            StackDetailView(stack: stack, client: client)
        }
    }
}
