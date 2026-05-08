import SwiftUI

/// Compose YAML editor. Read/write display of the stack file.
///
/// Note: actually persisting edits requires `PUT /stacks/{id}` which is not yet wired through
/// `PortainerClient` - see NOTES.md. For now the view shows the YAML and lets the user copy it.
struct StackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    let stackName: String
    @State private var copyFeedback = false

    init(initialContent: String, stackName: String) {
        _content = State(initialValue: initialContent)
        self.stackName = stackName
    }

    var body: some View {
        TextEditor(text: $content)
            .font(.system(.caption, design: .monospaced))
            .padding(DesignSystem.Spacing.small)
            .navigationTitle(stackName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .sensoryFeedback(.success, trigger: copyFeedback)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done", action: dismiss.callAsFunction)
        }
        ToolbarItem(placement: .platformTrailing) {
            Button("Copy", systemImage: "doc.on.doc", action: copy)
        }
    }

    private func copy() {
#if canImport(UIKit)
        UIPasteboard.general.string = content
#endif
        copyFeedback.toggle()
    }
}
