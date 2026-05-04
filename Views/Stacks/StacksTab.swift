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
                .hostTitleMenu()
                .navigationDestination(for: Stack.self) { stack in
                    StackDetailContainer(stack: stack)
                }
        }
    }
}

/// Resolves the active host and presents the stacks list, or a no-host placeholder.
struct StacksContainer: View {
    var body: some View {
        ActiveHostGate { host, client, endpointID in
            StacksListView(client: client, endpointID: endpointID)
                .id(host.id)
        }
    }
}

/// Resolves the host and presents the stack detail.
struct StackDetailContainer: View {
    let stack: Stack

    var body: some View {
        ActiveHostGate { _, client, endpointID in
            StackDetailView(stack: stack, client: client, endpointID: endpointID)
        }
    }
}
