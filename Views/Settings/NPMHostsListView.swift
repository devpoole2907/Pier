import SwiftUI
import SwiftData

struct NPMHostsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NPMHostManager.self) private var npmHostManager
    @Query(sort: \NPMHost.createdAt) private var hosts: [NPMHost]

    @State private var editMode: EditMode = .inactive
    @State private var selectedHostIDs: Set<UUID> = []
    @State private var editingHost: NPMHost?
    @State private var isAddingHost = false
    @State private var pendingDeleteHost: NPMHost?
    @State private var isShowingBulkDeleteAlert = false

    var body: some View {
        List(selection: $selectedHostIDs) {
            if hosts.isEmpty {
                ContentUnavailableView {
                    Label("No NPM hosts", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Add your first Nginx Proxy Manager host to get started.")
                }
            } else {
                ForEach(hosts) { host in
                    row(for: host)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("NPM Hosts")
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
                            Image(systemName: "xmark").accessibilityLabel("Done")
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
                NPMHostEditorView(host: host)
            }
        }
        .sheet(isPresented: $isAddingHost) {
            NavigationStack {
                NPMHostEditorView(host: nil)
            }
        }
        .alert("Delete selected hosts?", isPresented: $isShowingBulkDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSelectedHosts() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes \(selectedHosts.count) host\(selectedHosts.count == 1 ? "" : "s") and their saved credentials.")
        }
        .alert("Delete host?", isPresented: Binding(
            get: { pendingDeleteHost != nil },
            set: { if !$0 { pendingDeleteHost = nil } }
        ), presenting: pendingDeleteHost) { host in
            Button("Cancel", role: .cancel) { pendingDeleteHost = nil }
            Button("Delete", role: .destructive) { delete(host) }
        } message: { host in
            Text("This removes \(host.name) and its saved credentials.")
        }
    }

    @ViewBuilder
    private func row(for host: NPMHost) -> some View {
        if isSelecting {
            NPMHostRowView(host: host, isActive: host.id == npmHostManager.activeNPMHostID, activate: nil)
                .tag(host.id)
        } else {
            NPMHostRowView(host: host, isActive: host.id == npmHostManager.activeNPMHostID) {
                Task { await npmHostManager.setActive(host) }
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

    private var selectedHosts: [NPMHost] {
        hosts.filter { selectedHostIDs.contains($0.id) }
    }

    private var isSelecting: Bool {
        editMode.isEditing
    }

    private var selectionSubtitle: String? {
        selectedHostIDs.isEmpty ? nil : "\(selectedHostIDs.count) selected"
    }

    private var activeHostName: String? {
        hosts.first(where: { $0.id == npmHostManager.activeNPMHostID })?.name
    }

    private var navigationSubtitleText: String {
        selectionSubtitle ?? activeHostName ?? ""
    }

    private func deleteSelectedHosts() {
        for host in selectedHosts {
            npmHostManager.forget(host)
            modelContext.delete(host)
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            editMode = .inactive
        }
        selectedHostIDs.removeAll()
    }

    private func delete(_ host: NPMHost) {
        npmHostManager.forget(host)
        modelContext.delete(host)
        try? modelContext.save()
        pendingDeleteHost = nil
    }
}

private struct NPMHostRowView: View {
    let host: NPMHost
    let isActive: Bool
    let activate: (() -> Void)?

    var body: some View {
        Group {
            if let activate {
                Button(action: activate) { rowContent }
                    .buttonStyle(.plain)
                    .accessibilityHint("Activates this NPM host")
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(host.name)\(isActive ? ", active" : "")")
    }

    private var rowContent: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .imageScale(.large)
                .foregroundStyle(isActive ? DesignSystem.Colors.npm : .secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(host.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(host.baseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(DesignSystem.Colors.npm)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }
}
