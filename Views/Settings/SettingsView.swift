import SwiftUI
import SwiftData

/// Main settings screen. Splits configuration into sections: hosts, refresh, theme, display, about.
struct SettingsView: View {
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalRaw: Int = RefreshInterval.medium.rawValue
    @AppStorage("themePreference") private var themeRawValue: String = AppTheme.system.rawValue
    @AppStorage("showStoppedContainers") private var showStoppedContainers: Bool = true

    var body: some View {
        Form {
            Section("Hosts") {
                NavigationLink(value: SettingsRoute.hostsList) {
                    Label("Manage hosts", systemImage: "externaldrive")
                }
            }

            Section("Display") {
                Picker(selection: $themeRawValue) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                } label: {
                    Label("Theme", systemImage: "moonphase.first.quarter")
                }

                Toggle(isOn: $showStoppedContainers) {
                    Label("Show stopped containers", systemImage: "stop.circle")
                }
            }

            Section("Refresh") {
                Picker(selection: $refreshIntervalRaw) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                } label: {
                    Label("Auto-refresh", systemImage: "arrow.clockwise")
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(versionString)
                        .foregroundStyle(.secondary)
                }
                Link(destination: URL(string: "https://docs.portainer.io/api")!) {
                    Label("Portainer API docs", systemImage: "book")
                }
            }
        }
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .hostsList:
                HostsListView()
            case .editHost(let id):
                HostEditorContainer(hostID: id)
            case .newHost:
                HostEditorView(host: nil)
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Routes used by the Settings navigation stack.
enum SettingsRoute: Hashable {
    case hostsList
    case editHost(UUID)
    case newHost
}
