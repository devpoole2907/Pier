import SwiftUI

/// Simple native list of recent in-app notifications (success/error/progress banners that have
/// fired). Presented as a sheet from `AppRootView` via `InAppNotificationCenter.isPresentingRecentNotifications`.
struct RecentNotificationsView: View {
    @Environment(InAppNotificationCenter.self) private var notificationCenter
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if notificationCenter.recentNotifications.isEmpty {
                    EmptyStateView(
                        title: "No Notifications Yet",
                        systemImage: "bell.slash",
                        message: "Recent success and error notifications will appear here."
                    )
                } else {
                    List {
                        ForEach(notificationCenter.recentNotifications) { entry in
                            row(for: entry)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !notificationCenter.recentNotifications.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear All", role: .destructive) {
                            showClearConfirmation = true
                        }
                    }
                }
            }
            .alert("Clear Notifications?", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) {
                    notificationCenter.clearRecentNotifications()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All recent notifications will be removed.")
            }
        }
        .onAppear {
            notificationCenter.markAllRead()
        }
    }

    private func row(for entry: NotificationLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: entry.style))
                .font(.title3.weight(.semibold))
                .foregroundStyle(tintColor(for: entry.style))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                Text(entry.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(entry.timestamp.relativeShort)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                notificationCenter.removeNotification(id: entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let entry = notificationCenter.recentNotifications[index]
            notificationCenter.removeNotification(id: entry.id)
        }
    }

    private func icon(for style: InAppBannerStyle) -> String {
        switch style {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .progress: "arrow.triangle.2.circlepath"
        }
    }

    private func tintColor(for style: InAppBannerStyle) -> Color {
        switch style {
        case .success: .green
        case .error: .red
        case .progress: .blue
        }
    }
}

#Preview {
    RecentNotificationsView()
        .environment(InAppNotificationCenter(previewNotifications: [
            NotificationLogEntry(title: "Container Started", message: "plex", style: .success, source: .inApp, timestamp: .now),
            NotificationLogEntry(title: "Start Container Failed", message: "Connection refused", style: .error, source: .inApp, timestamp: .now.addingTimeInterval(-3600))
        ]))
}
