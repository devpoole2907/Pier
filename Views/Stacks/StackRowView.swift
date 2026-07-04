import SwiftUI

/// One row in the stacks list.
struct StackRowView: View {
    let stack: Stack

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "square.stack.3d.up.fill")
                .imageScale(.large)
                .foregroundStyle(stack.state.color)
                .frame(width: 32)
            // Status (e.g. "running(1)") is intentionally omitted here — the trailing state label
            // already reports it, so repeating it in a subtitle is redundant.
            Text(stack.name)
                .font(.body)
                .fontWeight(.medium)
            Spacer()
            Text(stack.state.label)
                .font(.caption)
                .foregroundStyle(stack.state.color)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stack.name), \(stack.state.label) stack")
    }
}
