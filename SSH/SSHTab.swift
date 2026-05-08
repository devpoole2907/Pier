import SwiftUI

struct SSHTab: View {
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @State private var isShowingSession = false

    var body: some View {
        NavigationStack {
            SSHProfileListView { profile in
                sshSessionStore.addSession(for: profile)
                isShowingSession = true
            }
        }
        .sheet(isPresented: $isShowingSession, onDismiss: {
            sshSessionStore.wantsKeyboard = false
        }) {
            NavigationStack {
                SSHSessionContainerView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
}
