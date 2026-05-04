import SwiftUI

/// Compact status badge used in container rows. Combines a colored dot with a label so that the
/// information is conveyed by both color *and* shape - important when "Differentiate Without Color"
/// is enabled (per `accessibility.md`).
struct StatusBadgeView: View {
    let status: ContainerStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .imageScale(.small)
            Text(status.displayName)
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(status.color.opacity(0.15))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(ContainerStatus.allCases, id: \.self) { status in
            StatusBadgeView(status: status)
        }
    }
    .padding()
}
