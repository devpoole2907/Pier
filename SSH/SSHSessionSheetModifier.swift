import SwiftUI

private struct SSHSessionSheetModifier: ViewModifier {
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Binding private var isPresented: Bool

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
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

extension View {
    func sshSessionSheet(isPresented: Binding<Bool>) -> some View {
        modifier(SSHSessionSheetModifier(isPresented: isPresented))
    }
}
