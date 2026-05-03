import SwiftUI

/// One row in the container list. Shows name, status, image, and uptime/since.
struct ContainerRowView: View {
    let container: Container

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                Text(container.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !container.status.isEmpty {
                    Text(container.status)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.small)
            StatusBadgeView(status: container.state)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(container.displayName), \(container.state.displayName), image \(container.image)")
    }
}

#Preview {
    List {
        // No previewable real data without a server; keep blank to avoid invented containers.
    }
}
