import SwiftUI

/// One row in the variables list: name, optional description, and value. Secret values are
/// masked by default and only shown after an explicit reveal (tap or eye button); the value can
/// always be copied to the clipboard without revealing it on screen.
struct VariableRowView: View {
    let variable: KomodoVariable

    @State private var isRevealed = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(variable.name)
                    .font(.body.monospaced())
                    .fontWeight(.medium)
                if !variable.description.isEmpty {
                    Text(variable.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(displayValue)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            if variable.isSecret {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isRevealed ? "Hide value" : "Reveal value")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard variable.isSecret else { return }
            isRevealed.toggle()
        }
        .contextMenu {
            Button {
                copyToClipboard()
            } label: {
                Label("Copy Value", systemImage: "doc.on.doc")
            }
            if variable.isSecret {
                Button {
                    isRevealed.toggle()
                } label: {
                    Label(
                        isRevealed ? "Hide Value" : "Reveal Value",
                        systemImage: isRevealed ? "eye.slash" : "eye"
                    )
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var displayValue: String {
        if variable.isSecret, !isRevealed {
            "••••••••"
        } else {
            variable.value.isEmpty ? "—" : variable.value
        }
    }

    private var accessibilityLabel: String {
        var label = variable.name
        if !variable.description.isEmpty {
            label += ", \(variable.description)"
        }
        if variable.isSecret, !isRevealed {
            label += ", secret value hidden"
        } else {
            label += ", value \(variable.value)"
        }
        return label
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = variable.value
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(variable.value, forType: .string)
        #endif
    }
}

#Preview {
    List {
        VariableRowView(
            variable: KomodoVariable(
                name: "APP_ENV",
                value: "production",
                description: "Deployment environment",
                isSecret: false
            )
        )
        VariableRowView(
            variable: KomodoVariable(
                name: "API_KEY",
                value: "super-secret-value",
                description: "",
                isSecret: true
            )
        )
    }
}
