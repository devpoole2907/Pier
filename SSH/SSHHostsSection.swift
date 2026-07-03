import SwiftUI

/// The "SSH Hosts" section shared by the standalone SSH list (`SSHProfileListView`) and the
/// unified `TerminalsTab`. Renders each `SSHProfile` as a tappable row that opens the session
/// (via the caller-supplied `openSession` closure), with swipe/context "Edit" — exactly matching
/// the pre-Terminals-tab SSH behaviour.
struct SSHHostsSection: View {
    let profiles: [SSHProfile]
    let openSession: (SSHProfile) -> Void
    @Binding var editTarget: SSHProfile?

    @Environment(SSHSessionStore.self) private var sshSessionStore

    var body: some View {
        Section("SSH Hosts") {
            if profiles.isEmpty {
                Text("No SSH hosts yet.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(profiles) { profile in
                    Button {
                        openSession(profile)
                    } label: {
                        SSHProfileRowView(profile: profile, isConnected: isConnected(profile))
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editTarget = profile
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            editTarget = profile
                        }
                    }
                }
            }
        }
    }

    private func isConnected(_ profile: SSHProfile) -> Bool {
        sshSessionStore.sessions.contains { $0.profile.id == profile.id && $0.connection.state == .connected }
    }
}
