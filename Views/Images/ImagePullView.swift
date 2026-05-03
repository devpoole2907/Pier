import SwiftUI

/// Sheet for pulling a new image. Single text field, accepts `name:tag` syntax.
struct ImagePullView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ImagesViewModel
    @State private var reference: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("e.g. nginx:latest", text: $reference)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    #if os(iOS)
                    .submitLabel(.go)
                    #endif
                    .onSubmit(pull)
            } header: {
                Text("Image reference")
            } footer: {
                Text("Defaults to the `latest` tag if no tag is provided.")
            }

            if viewModel.isPulling {
                Section {
                    HStack {
                        ProgressView()
                        Text("Pulling \(reference)…")
                    }
                }
            }

            if let error = viewModel.pullError {
                Section {
                    Text(error.errorDescription ?? "Unknown error")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Pull image")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .onAppear { isFieldFocused = true }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: dismiss.callAsFunction)
                .disabled(viewModel.isPulling)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Pull", action: pull)
                .disabled(reference.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isPulling)
        }
    }

    private func pull() {
        Task {
            await viewModel.pull(reference: reference)
            if viewModel.pullError == nil {
                dismiss()
            }
        }
    }
}
