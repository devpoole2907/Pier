import SwiftUI

/// Compose YAML editor. Displays the stack's compose file and writes edits back via Komodo's
/// `WriteStackFileContents` (wired through `StacksViewModel.saveFile`, passed in as `onSave`).
struct StackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    let filePath: String
    let stackName: String
    /// Persists the edited contents; returns whether the write succeeded.
    let onSave: (String) async -> Bool

    @State private var copyFeedback = false
    @State private var isSaving = false
    @State private var saveFailed = false

    init(initialContent: String, filePath: String, stackName: String, onSave: @escaping (String) async -> Bool) {
        _content = State(initialValue: initialContent)
        self.filePath = filePath
        self.stackName = stackName
        self.onSave = onSave
    }

    var body: some View {
        TextEditor(text: $content)
            .font(.system(.caption, design: .monospaced))
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .padding(DesignSystem.Spacing.small)
            .disabled(isSaving)
            .navigationTitle(stackName)
            .navigationSubtitle(filePath)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .sensoryFeedback(.success, trigger: copyFeedback)
            .alert("Couldn't save", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The compose file couldn't be written. Check your connection and try again.")
            }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: dismiss.callAsFunction)
                .disabled(isSaving)
        }
        ToolbarItem(placement: .platformTrailing) {
            Button("Copy", systemImage: "doc.on.doc", action: copy)
                .disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
            } else {
                Button("Save", action: save)
                    .fontWeight(.semibold)
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let ok = await onSave(content)
            isSaving = false
            if ok {
                dismiss()
            } else {
                saveFailed = true
            }
        }
    }

    private func copy() {
#if canImport(UIKit)
        UIPasteboard.general.string = content
#endif
        copyFeedback.toggle()
    }
}
