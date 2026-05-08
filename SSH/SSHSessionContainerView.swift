import SwiftData
import SwiftUI

/// Top-level view shown in the SSH sheet. Shows a session tab strip when more than one session exists.
struct SSHSessionContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SSHSessionStore.self) private var store

    @State private var showDisconnectAllConfirm = false
    @State private var sessionPendingClose: SSHSessionItem?
    @State private var showingAddSession = false

    var body: some View {
        VStack(spacing: 0) {
            if let session = store.activeSession {
                SSHSessionView(session: session)
                    .id(session.id)
            } else {
                missingSessionView
            }
        }
        .navigationTitle(store.activeSession?.sessionTitle ?? "SSH")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbarTitleMenu {
            ForEach(store.sessions) { session in
                Button {
                    store.activeSession = session
                } label: {
                    Text(session.sessionTitle)
                    if store.activeSession?.id == session.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            Button {
                showingAddSession = true
            } label: {
                Label("Add Session", systemImage: "plus")
            }
            if let activeSession = store.activeSession {
                Button {
                    Task { await activeSession.reconnect(modelContext: modelContext) }
                } label: {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) {
                    sessionPendingClose = activeSession
                } label: {
                    Label("Close Session", systemImage: "xmark")
                }
            }
        }
        .toolbar { toolbarContent }
        .alert("Close all SSH sessions?", isPresented: $showDisconnectAllConfirm) {
            Button("Close All", role: .destructive) {
                Task {
                    await store.disconnect()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(store.sessions.count) terminal sessions will be closed.")
        }
        .alert(
            "Close SSH session?",
            isPresented: Binding(
                get: { sessionPendingClose != nil },
                set: { if !$0 { sessionPendingClose = nil } }
            ),
            presenting: sessionPendingClose
        ) { session in
            Button("Close Session", role: .destructive) {
                Task {
                    await store.closeSession(session)
                    sessionPendingClose = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("\(session.sessionTitle) will be disconnected.")
        }
        .sheet(isPresented: $showingAddSession) {
            NavigationStack {
                SSHProfileListView { profile in
                    store.addSession(for: profile)
                    showingAddSession = false
                }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(24)
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                store.beginBackgroundKeepAlive()
            case .active:
                store.endBackgroundKeepAlive()
                if !store.sessions.isEmpty {
                    Task {
                        for session in store.sessions {
                            await session.connectIfNeeded(modelContext: modelContext)
                        }
                    }
                }
            default:
                break
            }
        }
        #endif
        .onChange(of: store.sessions.count) { _, count in
            if count == 0 { dismiss() }
        }
    }

    private var missingSessionView: some View {
        ContentUnavailableView {
            Label("No Active SSH Session", systemImage: "terminal")
        } description: {
            Text("Choose a saved host to start a terminal session.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if store.sessions.count > 1 {
                Button {
                    showDisconnectAllConfirm = true
                } label: {
                    Label("Close All", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                        .font(.system(size: 18))
                }
            } else {
                Button {
                    sessionPendingClose = store.activeSession
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                        .font(.system(size: 18))
                }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            if store.sessions.count == 1 {
                Button {
                    showingAddSession = true
                } label: {
                    Label("New Session", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .foregroundStyle(.green)
            }
        }
    }
}
