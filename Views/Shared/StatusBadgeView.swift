import SwiftUI

/// Compact status badge used in container rows. Combines a colored symbol with a label so that the
/// information is conveyed by both color *and* shape - important when "Differentiate Without Color"
/// is enabled (per `accessibility.md`).
struct StatusBadgeView: View {
    private let label: String
    private let symbolName: String
    private let color: Color
    private let showsProgress: Bool

    init(status: ContainerStatus) {
        self.label = status.displayName
        self.symbolName = status.symbolName
        self.color = status.color
        self.showsProgress = false
    }

    init(actionState: ContainerActionState) {
        self.label = actionState.displayName
        self.symbolName = actionState.symbolName
        self.color = actionState.color
        self.showsProgress = true
    }

    var body: some View {
        HStack(spacing: 4) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(color)
            } else {
                Image(systemName: symbolName)
                    .imageScale(.small)
            }
            Text(label)
                .font(.caption)
                .fontDesign(.rounded)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignSystem.Spacing.small)
        .padding(.vertical, DesignSystem.Spacing.tight)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
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
