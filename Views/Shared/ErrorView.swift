import SwiftUI

/// A friendly error UI used when a load fails. Wraps `ContentUnavailableView` so we get the
/// system look without re-implementing it.
struct ErrorView: View {
    let errorDescription: String?
    let retry: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    init(
        error: KomodoError,
        retry: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.errorDescription = error.errorDescription
        self.retry = retry
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    init(
        error: NPMError,
        retry: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.errorDescription = error.errorDescription
        self.retry = retry
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorDescription ?? "Unknown error")
        } actions: {
            if let retry {
                Button("Try again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
            }
        }
    }
}

#Preview {
    ErrorView(error: KomodoError.unauthorized, retry: { })
}
