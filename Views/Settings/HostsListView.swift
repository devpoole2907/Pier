import SwiftUI
import SwiftData

/// Hosts management screen. Lists saved hosts; tap to activate, swipe for Edit/Delete.
struct HostsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HostManager.self) private var hostManager
    @Query(sort: \Host.createdAt) private var hosts: [Host]

    @State private var editMode: EditMode = .inactive
    @State private var selectedHostIDs: Set<UUID> = []
    @State private var editingHost: Host?
    @State private var isAddingHost = false
    @State private var pendingDeleteHost: Host?
    @State private var isShowingBulkDeleteAlert = false

    var body: some View {
        List(selection: $selectedHostIDs) {
            if hosts.isEmpty {
                ContentUnavailableView {
                    Label("No hosts", systemImage: "externaldrive.badge.questionmark")
                } description: {
                    Text("Add your first Komodo host below.")
                }
            } else {
                ForEach(hosts) { host in
                    row(for: host)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Hosts")
        .navigationSubtitle(navigationSubtitleText)
        .toolbar {
            if !hosts.isEmpty {
                ToolbarItem(placement: .platformTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            editMode = isSelecting ? .inactive : .active
                        }
                        if !editMode.isEditing {
                            selectedHostIDs.removeAll()
                        }
                    } label: {
                        if isSelecting {
                            Image(systemName: "xmark")
                                .accessibilityLabel("Done")
                        } else {
                            Text("Select")
                        }
                    }
                }

                ToolbarSpacer(.fixed, placement: .platformTrailing)
            }

            ToolbarItem(placement: .platformTrailing) {
                if isSelecting {
                    Button("Delete selected", systemImage: "trash") {
                        isShowingBulkDeleteAlert = true
                    }
                    .disabled(selectedHostIDs.isEmpty)
                } else {
                    Button("Add host", systemImage: "plus") {
                        isAddingHost = true
                    }
                }
            }
        }
        .sheet(item: $editingHost) { host in
            NavigationStack {
                HostEditorView(host: host)
            }
        }
        .sheet(isPresented: $isAddingHost) {
            NavigationStack {
                HostEditorView(host: nil)
            }
        }
        .alert("Delete selected hosts?", isPresented: $isShowingBulkDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteSelectedHosts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes \(selectedHosts.count) host\(selectedHosts.count == 1 ? "" : "s") and their saved credentials. Connected containers on the servers are not affected.")
        }
        .alert("Delete host?", isPresented: Binding(
            get: { pendingDeleteHost != nil },
            set: { if !$0 { pendingDeleteHost = nil } }
        ), presenting: pendingDeleteHost) { host in
            Button("Cancel", role: .cancel) {
                pendingDeleteHost = nil
            }
            Button("Delete", role: .destructive) {
                delete(host)
            }
        } message: { host in
            Text("This removes \(host.name) and its saved credentials. Connected containers on the server are not affected.")
        }
    }

    @ViewBuilder
    private func row(for host: Host) -> some View {
        if isSelecting {
            HostRowView(host: host, isActive: host.id == hostManager.activeHostID, activate: nil)
                .tag(host.id)
        } else {
            HostRowView(host: host, isActive: host.id == hostManager.activeHostID) {
                Task { await hostManager.setActive(host) }
            }
            .tag(host.id)
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingDeleteHost = host
                }
                Button("Edit", systemImage: "pencil") {
                    editingHost = host
                }
                .tint(.orange)
            }
        }
    }

    private var selectedHosts: [Host] {
        hosts.filter { selectedHostIDs.contains($0.id) }
    }

    private var isSelecting: Bool {
        editMode.isEditing
    }

    private var selectionSubtitle: String? {
        selectedHostIDs.isEmpty ? nil : "\(selectedHostIDs.count) selected"
    }

    private var activeHostName: String? {
        hosts.first(where: { $0.id == hostManager.activeHostID })?.name
    }

    private var navigationSubtitleText: String {
        selectionSubtitle ?? activeHostName ?? ""
    }

    private func deleteSelectedHosts() {
        let hostsToDelete = selectedHosts
        for host in hostsToDelete {
            hostManager.forget(host)
            modelContext.delete(host)
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            editMode = .inactive
        }
        selectedHostIDs.removeAll()
    }

    private func delete(_ host: Host) {
        hostManager.forget(host)
        modelContext.delete(host)
        try? modelContext.save()
        pendingDeleteHost = nil
    }

}
