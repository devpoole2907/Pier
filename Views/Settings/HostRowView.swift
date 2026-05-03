import SwiftUI

/// One row in the hosts list. Tap activates the host; trailing swipe exposes Edit and Delete.
struct HostRowView: View {
    let host: Host
    let isActive: Bool
    let activate: () -> Void

    var body: some View {
        Button(action: activate) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                Image(systemName: "externaldrive.fill")
                    .imageScale(.large)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.tight) {
                    Text(host.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(host.baseURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(host.name)\(isActive ? ", active" : "")")
        .accessibilityHint("Activates this host")
    }
}
