import Foundation

#if os(iOS)
import ActivityKit

@MainActor
final class SSHLiveActivityManager {
    private var activity: Activity<SSHSessionActivityAttributes>?

    init() {
        // Don't blindly recover the first activity - wait for sync() to match by profileID
        activity = nil
    }

    func sync(
        sessionCount: Int,
        profileID: String?,
        hostDisplay: String,
        title: String,
        subtitle: String,
        statusText: String
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end()
            return
        }

        guard let profileID else {
            await end()
            return
        }

        let attributes = SSHSessionActivityAttributes(
            profileID: profileID,
            hostDisplay: hostDisplay
        )
        let content = ActivityContent(
            state: SSHSessionActivityAttributes.ContentState(
                title: title,
                subtitle: subtitle,
                statusText: statusText,
                sessionCount: sessionCount
            ),
            staleDate: Date(timeIntervalSinceNow: 3 * 60),
            relevanceScore: 100
        )

        // If no activity, try to recover from existing activities by profileID
        if activity == nil {
            activity = Activity<SSHSessionActivityAttributes>.activities.first {
                $0.attributes.profileID == attributes.profileID
            }
        }

        if let activity {
            if activity.attributes.profileID != attributes.profileID {
                await activity.end(nil, dismissalPolicy: .immediate)
                self.activity = nil
            } else {
                await activity.update(content)
                return
            }
        }

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
#else
@MainActor
final class SSHLiveActivityManager {
    func sync(sessionCount: Int, profileID: String?, hostDisplay: String, title: String, subtitle: String, statusText: String) {}
    func end() async {}
}
#endif
