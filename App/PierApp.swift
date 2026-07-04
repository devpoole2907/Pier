import SwiftUI
import SwiftData
#if os(iOS) && !targetEnvironment(macCatalyst)
import BackgroundTasks
#endif

@main
struct PierApp: App {
    @State private var hostManager = HostManager()
    @State private var npmHostManager = NPMHostManager()
    @State private var sshSessionStore = SSHSessionStore()
    @State private var inAppNotificationCenter = InAppNotificationCenter.shared
    @AppStorage("themePreference") private var themeRawValue: String = AppTheme.system.rawValue

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Host.self, NPMHost.self, SSHProfile.self, KomodoTerminalProfile.self, ContainerNote.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData model container: \(error)")
        }
    }()

    init() {
        do {
            try Libssh2RuntimeBootstrap.bootstrap()
        } catch {
            fatalError("Libssh2 bootstrap failed: \(error)")
        }

        #if os(iOS) && !targetEnvironment(macCatalyst)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SSHBackgroundService.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // Set expiration handler synchronously before dispatching to service
            task.expirationHandler = {
                Task { @MainActor in
                    await SSHBackgroundService.shared.handleExpiration(refreshTask)
                }
            }
            Task { @MainActor in
                SSHBackgroundService.shared.handleBackgroundTask(refreshTask)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(hostManager)
                .environment(npmHostManager)
                .environment(sshSessionStore)
                .environment(inAppNotificationCenter)
                .preferredColorScheme(currentTheme.colorScheme)
                .tint(DesignSystem.Colors.accent)
        }
        .defaultSize(width: 900, height: 600)
        .modelContainer(modelContainer)
        .commands {
            PierCommands(hostManager: hostManager)
            SidebarCommands()
        }
    }

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeRawValue) ?? .system
    }
}

private struct PierCommands: Commands {
    let hostManager: HostManager

    var body: some Commands {
        @Bindable var hostManager = hostManager

        CommandGroup(replacing: .newItem) {
            Button("New Host…") {
                hostManager.isPresentingHostEditor = true
            }
            .keyboardShortcut("n")
            .disabled(hostManager.isPresentingHostEditor)
        }
    }
}

private extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
