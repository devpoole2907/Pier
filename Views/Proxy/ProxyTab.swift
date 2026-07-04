import SwiftUI
import SwiftData

enum ProxyDestination: Hashable {
    case proxyHosts
    case redirectionHosts
    case deadHosts
    case streams
    case accessLists
    case certificates
}

enum ProxyDestinationAccent {
    case proxy
    case redirection
    case dead
    case stream
    case accessList
    case certificate

    var color: Color {
        switch self {
        case .proxy: DesignSystem.Colors.npm
        case .redirection: .orange
        case .dead: .red
        case .stream: .blue
        case .accessList: .purple
        case .certificate: .green
        }
    }

    var icon: String {
        switch self {
        case .proxy: "arrow.triangle.branch"
        case .redirection: "arrow.triangle.turn.up.right.diamond"
        case .dead: "xmark.octagon"
        case .stream: "arrow.left.arrow.right"
        case .accessList: "lock.shield"
        case .certificate: "checkmark.seal"
        }
    }
}

struct ProxyTab: View {
    @Environment(NPMHostManager.self) private var npmHostManager
    @Environment(\.modelContext) private var modelContext
    @State private var path: [ProxyDestination] = []

    var body: some View {
        @Bindable var npmHostManager = npmHostManager

        NavigationStack(path: $path) {
            Group {
                if !activeHostExists {
                    NoProxyConfiguredView()
                } else {
                    List {
                        Section {
                            NavigationLink(value: ProxyDestination.proxyHosts) {
                                proxyRow(
                                    accent: .proxy,
                                    title: "Proxy Hosts",
                                    subtitle: "Manage reverse-proxy entries and SSL"
                                )
                            }
                        }

                        Section {
                            NavigationLink(value: ProxyDestination.redirectionHosts) {
                                proxyRow(
                                    accent: .redirection,
                                    title: "Redirection Hosts",
                                    subtitle: "HTTP redirect rules for domains"
                                )
                            }

                            NavigationLink(value: ProxyDestination.deadHosts) {
                                proxyRow(
                                    accent: .dead,
                                    title: "404 Hosts",
                                    subtitle: "Custom 404 pages for unknown hosts"
                                )
                            }

                            NavigationLink(value: ProxyDestination.streams) {
                                proxyRow(
                                    accent: .stream,
                                    title: "Streams",
                                    subtitle: "TCP/UDP port forwarding"
                                )
                            }
                        }

                        Section {
                            NavigationLink(value: ProxyDestination.accessLists) {
                                proxyRow(
                                    accent: .accessList,
                                    title: "Access Lists",
                                    subtitle: "Basic auth and IP allow/deny rules"
                                )
                            }

                            NavigationLink(value: ProxyDestination.certificates) {
                                proxyRow(
                                    accent: .certificate,
                                    title: "Certificates",
                                    subtitle: "Let's Encrypt and custom SSL certs"
                                )
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
                }
            }
            .navigationTitle("Proxy")
            .npmHostTitleMenu()
            .toolbar { npmToolbar }
            .task(id: npmHostManager.activeNPMHostID) {
                npmHostManager.reconcileActiveHost(in: modelContext)
            }
            .navigationDestination(for: ProxyDestination.self) { destination in
                switch destination {
                case .proxyHosts:
                    ProxyHostListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.proxy)
                case .redirectionHosts:
                    RedirectionHostListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.redirection)
                case .deadHosts:
                    DeadHostListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.dead)
                case .streams:
                    StreamListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.stream)
                case .accessLists:
                    AccessListListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.accessList)
                case .certificates:
                    CertificateListContainer()
                        .proxyDestinationTitleStyle()
                        .proxyDestinationBackground(.certificate)
                }
            }
        }
        .sheet(isPresented: $npmHostManager.isPresentingHostEditor) {
            NavigationStack {
                NPMHostEditorView(host: npmHostManager.editingHost)
            }
        }
    }

    @ToolbarContentBuilder
    private var npmToolbar: some ToolbarContent {
        ToolbarItem(placement: .platformTrailing) {
            Button("Add Host", systemImage: "plus") {
                npmHostManager.editingHost = nil
                npmHostManager.isPresentingHostEditor = true
            }
            .labelStyle(.iconOnly)
        }
    }

    /// Whether the stored active NPM host actually exists in the store. Gating on this (rather than
    /// just `activeNPMHostID != nil`) means a stale id shows the not-configured CTA immediately,
    /// without a flash of the "could not be found" error before `reconcileActiveHost` runs.
    private var activeHostExists: Bool {
        guard let id = npmHostManager.activeNPMHostID else { return false }
        let descriptor = FetchDescriptor<NPMHost>(predicate: #Predicate { $0.id == id })
        return (((try? modelContext.fetch(descriptor).first) ?? nil) != nil)
    }

    private func proxyRow(accent: ProxyDestinationAccent, title: String, subtitle: String) -> some View {
        NavigationMenuRow(icon: accent.icon, color: accent.color, title: title, subtitle: subtitle)
    }
}

struct ProxyDestinationGradientBackground: View {
    let accent: ProxyDestinationAccent

    var body: some View {
        ZStack {
            // Solid base matching the inset-grouped list backdrop so the accent
            // tint fades into the list background (off-white / black) rather than white.
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
    func proxyDestinationTitleStyle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func proxyDestinationBackground(_ accent: ProxyDestinationAccent) -> some View {
        scrollContentBackground(.hidden)
            .background(ProxyDestinationGradientBackground(accent: accent))
    }
}
