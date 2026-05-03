import SwiftUI

/// One row in the images list.
struct ImageRowView: View {
    let image: DockerImage

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
            Text(image.displayName)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: DesignSystem.Spacing.medium) {
                Label(image.size.byteCountString, systemImage: "internaldrive")
                Label(image.created.relativeShort, systemImage: "calendar")
                if image.containers > 0 {
                    Label("In use by \(image.containers)", systemImage: "shippingbox")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
    }
}
