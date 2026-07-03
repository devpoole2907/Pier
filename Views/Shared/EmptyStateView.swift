import SwiftUI

/// Convenience wrapper around `ContentUnavailableView` for common empty-data scenarios.
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String?

    init(title: String, systemImage: String, message: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        title: "No containers",
        systemImage: "shippingbox",
        message: "This Komodo host has no Docker containers yet."
    )
}
