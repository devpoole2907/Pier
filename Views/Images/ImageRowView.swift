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
                metadataItem(systemImage: "internaldrive", text: image.size.byteCountString)
                metadataItem(systemImage: "calendar", text: image.created.relativeShort)
                if image.containers > 0 {
                    metadataItem(systemImage: "shippingbox", text: "In use by \(image.containers)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.tight)
        .accessibilityElement(children: .combine)
    }

    private func metadataItem(systemImage: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(text)
        }
    }
}
