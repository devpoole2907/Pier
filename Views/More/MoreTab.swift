import SwiftData
import SwiftUI

enum MoreDestination: Hashable {
    case servers
    case alerts
    case stacks
    case deployments
    case variables
    case images
    case settings
}

enum MoreDestinationAccent {
    case servers
    case alerts
    case stacks
    case deployments
    case variables
    case images
    case settings

    var color: Color {
        switch self {
        case .servers: .blue
        case .alerts: .red
        case .stacks: .indigo
        case .deployments: .teal
        case .variables: .brown
        case .images: .orange
        case .settings: .secondary
        }
    }
}

struct MoreTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    @State private var path: [MoreDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Monitoring") {
                    NavigationLink(value: MoreDestination.servers) {
                        moreRow(icon: "server.rack", color: MoreDestinationAccent.servers.color,
                                title: "Servers", subtitle: "Host CPU, memory, load, and disk")
                    }
                    NavigationLink(value: MoreDestination.alerts) {
                        moreRow(icon: "bell.badge.fill", color: MoreDestinationAccent.alerts.color,
                                title: "Alerts", subtitle: "Open and resolved alerts")
                    }
                }

                Section("Resources") {
                    NavigationLink(value: MoreDestination.stacks) {
                        moreRow(icon: "square.stack.3d.up.fill", color: MoreDestinationAccent.stacks.color,
                                title: "Stacks", subtitle: "Compose stacks and services")
                    }
                    NavigationLink(value: MoreDestination.deployments) {
                        moreRow(icon: "shippingbox.fill", color: MoreDestinationAccent.deployments.color,
                                title: "Deployments", subtitle: "Single-container deployments")
                    }
                    NavigationLink(value: MoreDestination.images) {
                        moreRow(icon: "photo.stack.fill", color: MoreDestinationAccent.images.color,
                                title: "Images", subtitle: "Docker images per server")
                    }
                    NavigationLink(value: MoreDestination.variables) {
                        moreRow(icon: "curlybraces", color: MoreDestinationAccent.variables.color,
                                title: "Variables", subtitle: "Global variables and secrets")
                    }
                }

                Section {
                    NavigationLink(value: MoreDestination.settings) {
                        moreRow(icon: "gearshape.fill", color: MoreDestinationAccent.settings.color,
                                title: "Settings", subtitle: "Hosts, display, refresh, and app preferences")
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            .toolbarTitleDisplayMode(.large)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("More")
            .navigationDestination(for: MoreDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MoreDestination) -> some View {
        switch destination {
        case .servers:
            ServersContainer()
                .navigationTitle("Servers")
                .hostTitleMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.servers)
        case .alerts:
            AlertsContainer()
                .hostTitleMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.alerts)
        case .stacks:
            StacksContainer()
                .navigationTitle("Stacks")
                .hostTitleMenu()
                .navigationDestination(for: Stack.self) { stack in
                    StackDetailContainer(stack: stack)
                }
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.stacks)
        case .deployments:
            DeploymentsContainer()
                .navigationTitle("Deployments")
                .hostTitleMenu()
                .serverScopeMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.deployments)
        case .variables:
            VariablesContainer()
                .navigationTitle("Variables")
                .hostTitleMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.variables)
        case .images:
            ImagesContainer()
                .navigationTitle("Images")
                .hostTitleMenu()
                .serverScopeMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.images)
        case .settings:
            SettingsView()
                .navigationTitle("Settings")
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.settings)
        }
    }

    private func moreRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        NavigationMenuRow(icon: icon, color: color, title: title, subtitle: subtitle)
    }
}

struct MoreDestinationGradientBackground: View {
    let accent: MoreDestinationAccent

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accent.color.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [accent.color.opacity(0.14), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    @ViewBuilder
    func moreDestinationTitleStyle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func moreDestinationBackground(_ accent: MoreDestinationAccent) -> some View {
        scrollContentBackground(.hidden)
            .background(MoreDestinationGradientBackground(accent: accent))
    }
}
