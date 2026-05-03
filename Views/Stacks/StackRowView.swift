import SwiftUI

/// One row in the stacks list.
struct StackRowView: View {
    let stack: Stack

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: "square.stack.3d.up.fill")
                .imageScale(.large)
                .foregroundStyle(stack.isActive ? Color.green : .secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(stack.name)
                    .font(.body)
                    .fontWeight(.medium)
                if let updated = stack.updateDate ?? stack.creationDate {
                    Text("Updated \(updated.relativeShort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(stack.isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundStyle(stack.isActive ? .green : .secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stack.name), \(stack.isActive ? "active" : "inactive") stack")
    }
}
