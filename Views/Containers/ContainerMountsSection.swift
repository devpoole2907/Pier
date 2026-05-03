import SwiftUI

/// Mounts/volumes section.
struct ContainerMountsSection: View {
    let mounts: [ContainerDetail.Mount]

    var body: some View {
        if !mounts.isEmpty {
            Section("Mounts") {
                ForEach(mounts) { mount in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                        HStack {
                            Label(mount.type.capitalized, systemImage: mount.type == "volume" ? "externaldrive" : "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !mount.readWrite {
                                Text("RO")
                                    .font(.caption2)
                                    .padding(.horizontal, DesignSystem.Spacing.small)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.tertiary))
                            }
                        }
                        Text(mount.source)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Image(systemName: "arrow.down")
                            .imageScale(.small)
                            .foregroundStyle(.tertiary)
                        Text(mount.destination)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .truncationMode(.middle)
                            .lineLimit(1)
                    }
                    .padding(.vertical, DesignSystem.Spacing.tight)
                }
            }
        }
    }
}
