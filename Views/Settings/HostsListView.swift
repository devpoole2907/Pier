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
                    Text("Add your first Portainer host below.")
                }
            } else {
                ForEach(hosts) { host in
                    row(for: host)
                }
            }
        }
        .navigationTitle("Hosts")
        .navigationSubtitle(navigationSubtitleText)
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { _, mode in
            if mode == .inactive {
                selectedHostIDs.removeAll()
            }
        }
        .toolbar {
            ToolbarItem(placement: toolbarLeadingPlacement) {
                if !hosts.isEmpty {
                    EditButton()
                }
            }
            ToolbarItem(placement: toolbarTrailingPlacement) {
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
            HostRowView(host: host, isActive: host.id == hostManager.activeHostID) { }
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

    private var isSelecting: Bool {
        editMode.isEditing
    }

    private var selectedHosts: [Host] {
        hosts.filter { selectedHostIDs.contains($0.id) }
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

    private var toolbarLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    private var toolbarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    private func deleteSelectedHosts() {
        let hostsToDelete = selectedHosts
        for host in hostsToDelete {
            hostManager.forget(host)
            modelContext.delete(host)
        }
        try? modelContext.save()
        editMode = .inactive
        selectedHostIDs.removeAll()
    }

    private func delete(_ host: Host) {
        hostManager.forget(host)
        modelContext.delete(host)
        try? modelContext.save()
        pendingDeleteHost = nil
    }
}
