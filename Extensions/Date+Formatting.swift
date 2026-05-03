import Foundation

extension Date {
    /// Compact relative string like "2h ago" or "just now". Used in dense list rows.
    var relativeShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
