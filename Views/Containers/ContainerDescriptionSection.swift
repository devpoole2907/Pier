import SwiftUI
import SwiftData

/// A free-text description the user can attach to a container. Persisted locally as a
/// `ContainerNote` (see that model for why it's local rather than a Komodo field). The note is
/// created lazily on first edit and updated in place thereafter.
struct ContainerDescriptionSection: View {
    let hostID: UUID
    let containerID: String

    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [ContainerNote]
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    init(hostID: UUID, containerID: String) {
        self.hostID = hostID
        self.containerID = containerID
        _notes = Query(filter: #Predicate<ContainerNote> { $0.containerID == containerID })
    }

    var body: some View {
        Section("Description") {
            TextField("Add a description…", text: $text, axis: .vertical)
                .lineLimit(3...10)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in save(newValue) }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done", systemImage: "checkmark") { isFocused = false }
                            .labelStyle(.iconOnly)
                            .fontWeight(.semibold)
                    }
                }
        }
        .task(id: notes.first?.persistentModelID) {
            // Seed the editor from the stored note without clobbering an in-progress edit.
            let stored = notes.first?.text ?? ""
            if text != stored { text = stored }
        }
    }

    private func save(_ newValue: String) {
        if let note = notes.first {
            guard note.text != newValue else { return }
            note.text = newValue
            note.updatedAt = .now
        } else if !newValue.isEmpty {
            modelContext.insert(ContainerNote(hostID: hostID, containerID: containerID, text: newValue))
        }
    }
}
