import SwiftUI

#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

@MainActor
@Observable
final class SSHSessionStore {
    private(set) var sessions: [SSHSessionItem] = []
    var activeSession: SSHSessionItem? {
        didSet {
            syncLiveActivity()
        }
    }
    private let liveActivityManager = SSHLiveActivityManager()

    #if os(iOS) && !targetEnvironment(macCatalyst)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif

    init() {
        Task {
            await liveActivityManager.end()
        }
    }

    var hasSession: Bool { !sessions.isEmpty }
    var activeProfile: SSHProfile? { activeSession?.profile }

    var sessionTitle: String {
        sessions.count > 1 ? "\(sessions.count) Sessions" : (activeSession?.sessionTitle ?? "SSH")
    }

    var sessionSubtitle: String {
        if sessions.count > 1 {
            let connected = sessions.filter { $0.connection.state == .connected }.count
            return "\(connected) connected"
        }
        return activeSession?.sessionSubtitle ?? "No Active Session"
    }

    var statusText: String {
        sessions.count > 1 ? "Active" : (activeSession?.statusText ?? "Disconnected")
    }

    var statusColor: Color {
        sessions.count > 1 ? .green : (activeSession?.statusColor ?? .secondary)
    }

    var wantsKeyboard: Bool {
        get { activeSession?.wantsKeyboard ?? false }
        set { activeSession?.wantsKeyboard = newValue }
    }

    @discardableResult
    func addSession(for profile: SSHProfile) -> SSHSessionItem {
        if let existing = sessions.first(where: { $0.profile.id == profile.id }) {
            activeSession = existing
            return existing
        }

        let item = SSHSessionItem(profile: profile)
        item.connection.onClose = { [weak self, weak item] in
            item?.wantsKeyboard = false
            self?.syncLiveActivity()
        }
        item.connection.onStateChange = { [weak self, weak item] newState in
            guard let self else { return }
            self.syncLiveActivity()
            #if os(iOS) && !targetEnvironment(macCatalyst)
            switch newState {
            case .connected:
                if let item { SSHBackgroundService.shared.register(id: item.id, connection: item.connection) }
                self.updateBackgroundService()
            case .disconnected, .failed:
                if let item { SSHBackgroundService.shared.unregister(id: item.id) }
                // End background task if no sessions are connected
                if !self.sessions.contains(where: { $0.connection.state == .connected }) {
                    self.endBackgroundKeepAlive()
                }
            case .connecting:
                break
            }
            #endif
        }
        sessions.append(item)
        activeSession = item
        syncLiveActivity()
        return item
    }

    func closeSession(_ item: SSHSessionItem) async {
        sessions.removeAll { $0.id == item.id }
        if activeSession?.id == item.id {
            activeSession = sessions.last
        }
        syncLiveActivity()
        await item.disconnect()
    }

    func closeSessions(for profileID: UUID) async {
        let matchingSessions = sessions.filter { $0.profile.id == profileID }
        guard !matchingSessions.isEmpty else { return }

        sessions.removeAll { $0.profile.id == profileID }
        if let activeSession, activeSession.profile.id == profileID {
            self.activeSession = sessions.last
        }
        syncLiveActivity()

        for item in matchingSessions {
            await item.disconnect()
        }
    }

    func disconnect(animated: Bool = false) async {
        let itemsToDisconnect = sessions
        let clearSessions = {
            self.sessions.removeAll()
            self.activeSession = nil
            self.syncLiveActivity()
        }
        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                clearSessions()
            }
        } else {
            clearSessions()
        }
        for item in itemsToDisconnect {
            await item.disconnect()
        }
    }

    func focusSession() { activeSession?.focusSession() }

    func hideKeyboard() {
        activeSession?.hideKeyboard()
        for item in sessions where item.id != activeSession?.id {
            item.hideKeyboard()
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func beginBackgroundKeepAlive() {
        guard backgroundTaskID == .invalid,
              sessions.contains(where: { $0.connection.state == .connected }) else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SSHKeepAlive") { [weak self] in
            self?.endBackgroundKeepAlive()
        }
    }

    func endBackgroundKeepAlive() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func updateBackgroundService() {
        SSHBackgroundService.shared.setLiveActivitySync { [weak self] in
            self?.syncLiveActivity()
        }
    }
    #endif

    func syncLiveActivity() {
        // Spawn a task to call the async sync method
        // The async nature of sync() prevents concurrent interleaving
        Task {
            guard let rep = activeSession ?? sessions.first else {
                await liveActivityManager.sync(
                    sessionCount: 0,
                    profileID: nil,
                    hostDisplay: "",
                    title: "SSH",
                    subtitle: "No Active Session",
                    statusText: "Disconnected"
                )
                return
            }
            await liveActivityManager.sync(
                sessionCount: sessions.count,
                profileID: rep.profile.id.uuidString,
                hostDisplay: rep.profile.hostDisplay,
                title: sessionTitle,
                subtitle: sessionSubtitle,
                statusText: statusText
            )
        }
    }
}
