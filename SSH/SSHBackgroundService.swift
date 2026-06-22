import Foundation
import OSLog

#if os(iOS) && !targetEnvironment(macCatalyst)
import BackgroundTasks

/// App-level singleton that bridges BGAppRefreshTask to all active SSHConnections.
/// SSHSessionStore registers each connection when state becomes .connected
/// and unregisters on disconnect/failed.
@MainActor
final class SSHBackgroundService {
    static let shared = SSHBackgroundService()
    static let taskIdentifier = "com.poole.james.pier.sshKeepalive"

    private let logger = Logger(subsystem: "com.poole.james.pier", category: "SSHBackground")
    private var connections: [UUID: SSHConnection] = [:]
    private var liveActivitySync: (() -> Void)?
    private var taskCompleted = false

    private init() {}

    // MARK: - Registration

    func register(id: UUID, connection: SSHConnection) {
        connections[id] = connection
        if connections.count == 1 {
            scheduleNextTask()
        }
        logger.info("SSH background keepalive registered (total: \(self.connections.count, privacy: .public)).")
    }

    func unregister(id: UUID) {
        connections.removeValue(forKey: id)
        if connections.isEmpty {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            logger.info("All SSH sessions unregistered — BGTask cancelled.")
        } else {
            logger.info("SSH session unregistered (remaining: \(self.connections.count, privacy: .public)).")
        }
    }

    func setLiveActivitySync(_ sync: @escaping () -> Void) {
        self.liveActivitySync = sync
    }

    // MARK: - BGTask Handling

    func handleExpiration(_ task: BGAppRefreshTask) async {
        // Mirror expiration logic - cancel ongoing work and mark as failed
        if !taskCompleted {
            taskCompleted = true
            task.setTaskCompleted(success: false)
        }
    }

    func handleBackgroundTask(_ task: BGAppRefreshTask) {
        taskCompleted = false
        scheduleNextTask()

        let bgTask = Task { @MainActor in
            let activeConnections = self.connections.values.filter { $0.state == .connected }
            if activeConnections.isEmpty {
                self.logger.info("BGTask fired — no connected SSH sessions.")
            } else {
                await withTaskGroup(of: Void.self) { group in
                    for conn in activeConnections {
                        group.addTask { await conn.sendBackgroundKeepalive() }
                    }
                }
                self.logger.info("BGTask: keepalives sent to \(activeConnections.count, privacy: .public) sessions.")
            }
            if !self.taskCompleted {
                self.taskCompleted = true
                self.liveActivitySync?()
                task.setTaskCompleted(success: true)
            }
        }

        task.expirationHandler = {
            bgTask.cancel()
            Task { @MainActor in
                await SSHBackgroundService.shared.handleExpiration(task)
            }
        }
    }

    // MARK: - Scheduling

    private func scheduleNextTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2.5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.notPermitted {
            logger.warning("BGTask not permitted — Background App Refresh may be disabled in Settings.")
        } catch {
            logger.error("Failed to schedule SSH keepalive BGTask: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#endif
