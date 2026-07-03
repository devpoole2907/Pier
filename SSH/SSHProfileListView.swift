import SwiftUI
import SwiftData

struct SSHProfileListView: View {
    let openSession: (SSHProfile) -> Void

    @Query(sort: \SSHProfile.createdAt) private var profiles: [SSHProfile]
    @State private var showAddSheet = false
    @State private var editTarget: SSHProfile?
    @Environment(SSHSessionStore.self) private var sshSessionStore

    var body: some View {
        Group {
            if profiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .navigationTitle("SSH")
        #if os(iOS)
        .toolbarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Server", systemImage: "plus") {
                    showAddSheet = true
                }
                .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            SSHProfileEditSheet(existing: nil)
        }
        .sheet(item: $editTarget) { profile in
            SSHProfileEditSheet(existing: profile)
        }
    }

    // MARK: - Profile List

    private var profileList: some View {
        List {
            SSHHostsSection(profiles: profiles, openSession: openSession, editTarget: $editTarget)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private var currentSessionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.green.opacity(0.16))
                    .frame(width: 50, height: 50)
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sshSessionStore.sessionTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(sshSessionStore.sessionSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(sshSessionStore.statusColor)
                        .frame(width: 8, height: 8)
                    Text(sshSessionStore.statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("Tap to resume")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No SSH Servers", systemImage: "terminal")
        } description: {
            Text("Add a server to open a secure terminal session.")
        } actions: {
            Button("Add Server", systemImage: "plus") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
}
