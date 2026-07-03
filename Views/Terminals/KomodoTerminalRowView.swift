import SwiftUI

/// Row for a single Komodo terminal target (server/container/stack/deployment) inside
/// `TerminalsTab`'s Komodo sections. Mirrors the visual language of `SSHProfileRowView` (icon
/// square + name/subtitle) but tinted with the Komodo brand accent rather than SSH's green.
struct KomodoTerminalRowView: View {
    let icon: String
    let name: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(DesignSystem.Colors.accent.opacity(0.14))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
