import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

@main
struct PierApp: App {
    @State private var hostManager = HostManager()
    @State private var sshSessionStore = SSHSessionStore()
    @AppStorage("themePreference") private var themeRawValue: String = AppTheme.system.rawValue

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Host.self, SSHProfile.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData model container: \(error)")
        }
    }()

    init() {
        try? Libssh2RuntimeBootstrap.bootstrap()

        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SSHBackgroundService.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
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
                .environment(sshSessionStore)
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
