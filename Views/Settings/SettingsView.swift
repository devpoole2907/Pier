import SwiftUI
import SwiftData

/// Main settings screen. Splits configuration into sections: hosts, refresh, theme, display, about.
struct SettingsView: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(NPMHostManager.self) private var npmHostManager
    @AppStorage("refreshIntervalSeconds") private var refreshIntervalRaw: Int = RefreshInterval.medium.rawValue
    @AppStorage("themePreference") private var themeRawValue: String = AppTheme.system.rawValue
    @AppStorage("showStoppedContainers") private var showStoppedContainers: Bool = true
    @Query(sort: \Host.createdAt) private var hosts: [Host]
    @Query(sort: \NPMHost.createdAt) private var npmHosts: [NPMHost]

    var body: some View {
        Form {
            Section("Hosts") {
                NavigationLink {
                    HostsListView()
                } label: {
                    LabeledContent {
                        Text(activeHostName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } label: {
                        Label("Manage Portainer hosts", systemImage: "externaldrive")
                    }
                }
            }

            Section("Nginx Proxy Manager") {
                NavigationLink {
                    NPMHostsListView()
                } label: {
                    LabeledContent {
                        Text(activeNPMHostName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } label: {
                        Label("Manage NPM hosts", systemImage: "arrow.triangle.branch")
                    }
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
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var activeHostName: String {
        guard let activeHostID = hostManager.activeHostID,
              let activeHost = hosts.first(where: { $0.id == activeHostID }) else {
            return "None"
        }
        return activeHost.name
    }

    private var activeNPMHostName: String {
        guard let activeID = npmHostManager.activeNPMHostID,
              let active = npmHosts.first(where: { $0.id == activeID }) else {
            return "None"
        }
        return active.name
    }
}
