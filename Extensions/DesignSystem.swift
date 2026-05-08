import SwiftUI

/// Centralised design tokens. Pulled from `design.md` guidance: defining shared spacing, rounding,
/// and animation timings up front means the look stays consistent and is trivially adjustable.
enum DesignSystem {
    enum Colors {
        /// Portainer's current default "purple" active brand color from portainer.io.
        static let accent = Color(red: 192 / 255, green: 128 / 255, blue: 1)
    }

    enum Spacing {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    enum Animation {
        static let standard: SwiftUI.Animation = .smooth(duration: 0.25)
        static let bouncy: SwiftUI.Animation = .bouncy(duration: 0.4)
    }

    enum Limits {
        /// Maximum stat samples kept in memory for sparklines.
        static let maxStatsSamples = 60
        /// Maximum log lines kept in the UI buffer.
        static let maxLogLines = 5_000
    }
}

extension ToolbarItemPlacement {
    static var platformLeading: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .automatic
        #endif
    }

    static var platformTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }
}

extension Set {
    mutating func toggleMembership(of element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}
