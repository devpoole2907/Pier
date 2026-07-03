import SwiftUI

struct WelcomeFlowView: View {
    @Binding var isInWelcomeFlow: Bool
    @Binding var setupTarget: SetupTarget?
    let configuredServices: WelcomeServicesState

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var welcomePath: [WelcomeStep] = []

    var body: some View {
        NavigationStack(path: $welcomePath) {
            introScreen
                .navigationDestination(for: WelcomeStep.self) { step in
                    switch step {
                    case .services:
                        serviceSelectionScreen
                    }
                }
        }
    }

    private var introScreen: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Welcome to Pier")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your home for containers, proxies, and secure shell.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                WelcomeFeatureRow(
                    icon: PierServiceIdentity.komodo.systemImage,
                    color: PierServiceIdentity.komodo.brandColor,
                    title: "Komodo",
                    description: "Connect to your Docker control plane"
                )
                WelcomeFeatureRow(
                    icon: AppDestination.containers.systemImage,
                    color: PierServiceIdentity.komodo.brandColor,
                    title: "Containers",
                    description: "Start, stop, inspect, and monitor containers"
                )
                WelcomeFeatureRow(
                    icon: AppDestination.stacks.systemImage,
                    color: .indigo,
                    title: "Stacks",
                    description: "Review Compose stacks and service health"
                )
                WelcomeFeatureRow(
                    icon: PierServiceIdentity.nginxProxyManager.systemImage,
                    color: PierServiceIdentity.nginxProxyManager.brandColor,
                    title: "Nginx Proxy Manager",
                    description: "Manage proxy hosts, certificates, and streams"
                )
                WelcomeFeatureRow(
                    icon: PierServiceIdentity.ssh.systemImage,
                    color: PierServiceIdentity.ssh.brandColor,
                    title: "SSH",
                    description: "Open secure terminal sessions"
                )
            }
            .padding(.horizontal, 8)
        }
        .padding(32)
        .frame(maxWidth: hSizeClass == .regular ? 600 : 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .prominentBottomButton("Get Started") {
            welcomePath.append(.services)
        }
    }

    private var serviceSelectionScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Choose Your Services")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Set up the services you want to use, then continue into the app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    WelcomeSetupRow(
                        icon: PierServiceIdentity.komodo.systemImage,
                        color: PierServiceIdentity.komodo.brandColor,
                        title: PierServiceIdentity.komodo.displayName,
                        description: "Manage servers, containers, stacks, and stats",
                        isConfigured: configuredServices.komodo
                    ) {
                        setupTarget = .komodo
                    }

                    WelcomeSetupRow(
                        icon: PierServiceIdentity.nginxProxyManager.systemImage,
                        color: PierServiceIdentity.nginxProxyManager.brandColor,
                        title: PierServiceIdentity.nginxProxyManager.displayName,
                        description: "Manage proxy hosts, certificates, streams, and access lists",
                        isConfigured: configuredServices.nginxProxyManager
                    ) {
                        setupTarget = .nginxProxyManager
                    }

                    WelcomeSetupRow(
                        icon: PierServiceIdentity.ssh.systemImage,
                        color: PierServiceIdentity.ssh.brandColor,
                        title: PierServiceIdentity.ssh.displayName,
                        description: "Save servers for secure terminal sessions",
                        isConfigured: configuredServices.ssh
                    ) {
                        setupTarget = .ssh
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: hSizeClass == .regular ? 600 : 440)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .prominentBottomButton("Go", isDisabled: !configuredServices.hasAny) {
            withAnimation { isInWelcomeFlow = false }
        }
        .navigationTitle("Choose Services")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
