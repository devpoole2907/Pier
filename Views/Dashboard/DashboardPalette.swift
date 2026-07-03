import SwiftUI

/// Fixed-order categorical colors for identifying entities (servers today; other per-service
/// identities later) across Dashboard charts. Assigned by a stable sort position rather than
/// cycled/regenerated on every refresh, so a given entity keeps the same color across reloads
/// even as other servers come and go. Native SwiftUI system colors are used (instead of fixed
/// hex) so every step stays legible in both light and dark mode automatically.
enum DashboardPalette {
    static let series: [Color] = [.blue, .teal, .orange, .green, .purple, .pink, .indigo, .yellow]

    /// Maps `id` to a color by its index within `orderedIDs` (pass a stably-sorted id list, e.g.
    /// servers sorted by name). Falls back to the first slot if `id` isn't present, and cycles
    /// past the eighth entity rather than crashing.
    static func color(for id: String, orderedIDs: [String]) -> Color {
        guard let index = orderedIDs.firstIndex(of: id) else { return series[0] }
        return series[index % series.count]
    }
}
