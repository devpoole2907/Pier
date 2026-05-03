import SwiftUI

/// Spinner with an optional message. Used when nothing is shown yet but data is loading.
struct LoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

#Preview {
    LoadingView(message: "Loading containers…")
}
