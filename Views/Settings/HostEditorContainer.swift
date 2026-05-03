import SwiftUI
import SwiftData

/// Resolves a host UUID to its `Host` model and presents the editor.
/// Used when navigating from the hosts list to edit an existing host.
struct HostEditorContainer: View {
    let hostID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var hosts: [Host]

    init(hostID: UUID) {
        self.hostID = hostID
        _hosts = Query(filter: #Predicate<Host> { $0.id == hostID })
    }

    var body: some View {
        if let host = hosts.first {
            HostEditorView(host: host)
        } else {
            EmptyStateView(title: "Host not found", systemImage: "questionmark.circle")
        }
    }
}
