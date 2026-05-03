import SwiftUI
import SwiftData

/// Hosts management screen. Lists saved hosts; tap to activate, swipe for Edit/Delete.
struct HostsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HostManager.self) private var hostManager
    @Query(sort: \Host.createdAt) private var hosts: [Host]

    var body: some View {
        List {
            if hosts.isEmpty {
                ContentUnavailableView {
                    Label("No hosts", systemImage: "externaldrive.badge.questionmark")
                } description: {
                    Text("Add your first Portainer host below.")
                }
            } else {
                ForEach(hosts) { host in
                    HostRowView(host: host, isActive: host.id == hostManager.activeHostID) {
                        Task { await hostManager.setActive(host) }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(host)
                        }
                        NavigationLink(value: SettingsRoute.editHost(host.id)) {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Hosts")
        .toolbar {
            ToolbarItem(placement: toolbarTrailingPlacement) {
                NavigationLink(value: SettingsRoute.newHost) {
                    Label("Add host", systemImage: "plus")
                }
            }
        }
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    private func delete(_ host: Host) {
        hostManager.forget(host)
        modelContext.delete(host)
        try? modelContext.save()
    }
}
