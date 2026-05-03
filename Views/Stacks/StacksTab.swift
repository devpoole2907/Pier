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
                .navigationDestination(for: Stack.self) { stack in
                    StackDetailContainer(stack: stack)
                }
        }
    }
}

/// Resolves the active host and presents the stacks list, or a no-host placeholder.
struct StacksContainer: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            StacksListView(client: active.client, endpointID: active.endpointID)
                .id(active.host.id)
        } else {
            NoHostConfiguredView()
        }
    }
}

/// Resolves the host and presents the stack detail.
struct StackDetailContainer: View {
    let stack: Stack
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let active = hostManager.activeClient(in: modelContext) {
            StackDetailView(stack: stack, client: active.client, endpointID: active.endpointID)
        } else {
            EmptyStateView(title: "No active host", systemImage: "externaldrive.badge.questionmark")
        }
    }
}
