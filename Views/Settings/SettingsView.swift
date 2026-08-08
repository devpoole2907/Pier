import SwiftUI
import SwiftData

/// Main settings screen. Splits configuration into sections: integrations, refresh, theme, display, about.
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
            Section("Komodo") {
                NavigationLink {
                    HostEditorView(host: configuredKomodoHost)
                } label: {
                    LabeledContent {
                        Text(configuredKomodoHost?.name ?? "Not configured")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } label: {
                        Label("Komodo Core", systemImage: "externaldrive")
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
                Link(destination: URL(string: "https://komo.do/docs/api")!) {
                    Label("Komodo API docs", systemImage: "book")
                }
            }
        }
        .softScrollEdges()
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var configuredKomodoHost: Host? {
        if let activeHostID = hostManager.activeHostID,
           let activeHost = hosts.first(where: { $0.id == activeHostID }) {
            return activeHost
        }
        return hosts.first
    }

    private var activeNPMHostName: String {
        guard let activeID = npmHostManager.activeNPMHostID,
              let active = npmHosts.first(where: { $0.id == activeID }) else {
            return "None"
        }
        return active.name
    }
}
