import SwiftUI

extension View {
    /// Shared "dashboard card" chrome: padded content on a rounded, native material background.
    /// Every card on the Dashboard (today's Servers cards, tomorrow's Proxy/SSH cards) uses this
    /// so the surface stays visually consistent without each card re-declaring the styling.
    func dashboardCardStyle() -> some View {
        padding(DesignSystem.Spacing.large)
            .background(.regularMaterial, in: .rect(cornerRadius: DesignSystem.Radius.large))
    }
}
