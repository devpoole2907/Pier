import SwiftUI

/// A friendly error UI used when a load fails. Wraps `ContentUnavailableView` so we get the
/// system look without re-implementing it.
struct ErrorView: View {
    let error: PortainerError
    let retry: (() -> Void)?

    init(error: PortainerError, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.errorDescription ?? "Unknown error")
        } actions: {
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ErrorView(error: .unauthorized) { }
}
