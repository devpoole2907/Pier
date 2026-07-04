import SwiftData
import SwiftUI

enum MoreDestination: Hashable {
    case servers
    case alerts
    case containers
    case deployments
    case variables
    case images
    case procedures
    case settings
}

enum MoreDestinationAccent {
    case servers
    case alerts
    case containers
    case deployments
    case variables
    case images
    case procedures
    case settings

    var color: Color {
        switch self {
        case .servers: .blue
        case .alerts: .red
        case .containers: .cyan
        case .deployments: .teal
        case .variables: .brown
        case .images: .orange
        case .procedures: .purple
        case .settings: .secondary
        }
    }
}

struct MoreTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(\.modelContext) private var modelContext
    // Type-erased: a homogeneous `[MoreDestination]` path can only hold MoreDestination values, so
    // pushing a `Stack` (from a stack-row NavigationLink) would silently no-op. NavigationPath
    // carries both MoreDestination and Stack pushes.
    @State private var path = NavigationPath()

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
                    NavigationLink(value: MoreDestination.containers) {
                        moreRow(icon: "shippingbox.fill", color: MoreDestinationAccent.containers.color,
                                title: "Containers", subtitle: "Running containers and images")
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

                Section("Automation") {
                    NavigationLink(value: MoreDestination.procedures) {
                        moreRow(icon: "list.bullet.clipboard.fill", color: MoreDestinationAccent.procedures.color,
                                title: "Procedures", subtitle: "Run multi-stage automation")
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
            .toolbarTitleDisplayMode(.inlineLarge)
            #else
            .listStyle(.inset)
            #endif
            .softScrollEdges()
            .navigationTitle("More")
            .navigationDestination(for: MoreDestination.self) { destination in
                destinationView(for: destination)
            }
            // Declared at the stack root (not inside the pushed Stacks destination) so the push
            // actually registers — a nested navigationDestination leaves stack-row taps as a
            // highlight that goes nowhere.
            .navigationDestination(for: Stack.self) { stack in
                StackDetailContainer(stack: stack)
            }
            // Stack detail links its services to container detail, so this stack must know how to
            // resolve a ContainerNavigationValue too (it's only registered in ContainersTab
            // otherwise).
            .navigationDestination(for: ContainerNavigationValue.self) { value in
                ContainerDetailContainer(navigationValue: value)
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
        case .containers:
            ContainerListContainer()
                .navigationTitle("Containers")
                .hostTitleMenu()
                .serverScopeMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.containers)
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
        case .procedures:
            ProceduresContainer()
                .hostTitleMenu()
                .moreDestinationTitleStyle()
                .moreDestinationBackground(.procedures)
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
            // Solid base matching the inset-grouped list backdrop so the accent tint fades into the
            // grouped-list background (off-white in light mode / black in dark) rather than pure
            // white. Mirrors ProxyDestinationGradientBackground.
            Color.groupedListBackground

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
