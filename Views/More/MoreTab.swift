import SwiftData
import SwiftUI

enum MoreDestination: Hashable {
    case stats
    case settings
    case images
}

enum MoreDestinationAccent {
    case stats
    case settings
    case images

    var color: Color {
        switch self {
        case .stats: .blue
        case .settings: .secondary
        case .images: .orange
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
                Section {
                    NavigationLink(value: MoreDestination.stats) {
                        moreRow(
                            icon: "chart.line.uptrend.xyaxis",
                            color: MoreDestinationAccent.stats.color,
                            title: "Stats",
                            subtitle: "Live CPU, memory, and container metrics"
                        )
                    }

                    NavigationLink(value: MoreDestination.images) {
                        moreRow(
                            icon: "photo.stack.fill",
                            color: MoreDestinationAccent.images.color,
                            title: "Images",
                            subtitle: "Browse local images and pull new ones"
                        )
                    }
                }

                Section {
                    NavigationLink(value: MoreDestination.settings) {
                        moreRow(
                            icon: "gearshape.fill",
                            color: MoreDestinationAccent.settings.color,
                            title: "Settings",
                            subtitle: "Hosts, display, refresh, and app preferences"
                        )
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
                switch destination {
                case .stats:
                    StatsMoreDestination()
                        .moreDestinationTitleStyle()
                        .moreDestinationBackground(.stats)
                case .settings:
                    SettingsView()
                        .navigationTitle("Settings")
                        .moreDestinationTitleStyle()
                        .moreDestinationBackground(.settings)
                case .images:
                    ImagesMoreDestination()
                        .moreDestinationTitleStyle()
                        .moreDestinationBackground(.images)
                }
            }
        }
    }

    private func moreRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        NavigationMenuRow(icon: icon, color: color, title: title, subtitle: subtitle)
    }
}

private struct StatsMoreDestination: View {
    var body: some View {
        StatsContainer()
            .navigationTitle("Stats")
            .hostTitleMenu()
    }
}

private struct ImagesMoreDestination: View {
    var body: some View {
        ImagesContainer()
            .navigationTitle("Images")
            .hostTitleMenu()
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
