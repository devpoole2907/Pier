import SwiftData
import SwiftUI

enum MoreDestination: Hashable {
    case ssh
    case settings
    case images
}

enum MoreDestinationAccent {
    case ssh
    case settings
    case images

    var color: Color {
        switch self {
        case .ssh: .green
        case .settings: .secondary
        case .images: .orange
        }
    }
}

struct MoreTab: View {
    @Environment(HostManager.self) private var hostManager
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Environment(\.modelContext) private var modelContext
    @State private var path: [MoreDestination] = []
    @State private var isShowingSession = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: MoreDestination.ssh) {
                        moreRow(
                            icon: "terminal.fill",
                            color: MoreDestinationAccent.ssh.color,
                            title: "SSH",
                            subtitle: sshSessionStore.hasSession ? "Profiles and active shell access" : "Profiles and remote shell access"
                        )
                    }
                }

                Section {
                    NavigationLink(value: MoreDestination.images) {
                        moreRow(
                            icon: "photo.stack.fill",
                            color: MoreDestinationAccent.images.color,
                            title: "Images",
                            subtitle: "Browse local images and pull new ones"
                        )
                    }

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
                case .ssh:
                    SSHMoreDestination(isShowingSession: $isShowingSession)
                        .moreDestinationTitleStyle()
                        .moreDestinationBackground(.ssh)
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
        .sshSessionSheet(isPresented: $isShowingSession)
    }

    private func moreRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        NavigationMenuRow(icon: icon, color: color, title: title, subtitle: subtitle)
    }
}

private struct SSHMoreDestination: View {
    @Environment(SSHSessionStore.self) private var sshSessionStore
    @Binding var isShowingSession: Bool

    var body: some View {
        SSHProfileListView { profile in
            sshSessionStore.addSession(for: profile)
            isShowingSession = true
        }
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
