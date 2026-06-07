import SwiftUI

struct ProxyHostDetailView: View {
    let host: NPMProxyHost
    let isEnabled: Bool

    var body: some View {
        List {
            Section("Domains") {
                ForEach(host.domain_names, id: \.self) { domain in
                    Text(domain)
                        .font(.callout)
                }
            }

            Section("Forward") {
                LabeledContent("Scheme", value: host.forward_scheme ?? "http")
                LabeledContent("Host", value: host.forward_host)
                LabeledContent("Port", value: String(host.forward_port))
            }

            Section("Status") {
                LabeledContent("Enabled", value: isEnabled ? "Yes" : "No")
                if let cert = host.certificate {
                    LabeledContent("Certificate", value: cert.nice_name)
                }
                if let accessList = host.access_list {
                    LabeledContent("Access List", value: accessList.name)
                }
                if let owner = host.owner {
                    LabeledContent("Owner", value: owner.email)
                }
            }

            if let ssl = host.ssl_forced, ssl.boolValue || (host.http2_support?.boolValue ?? false) {
                Section("SSL") {
                    if let ssl = host.ssl_forced, ssl.boolValue {
                        LabeledContent("SSL Forced", value: "Yes")
                    }
                    if let hsts = host.hsts_enabled, hsts.boolValue {
                        LabeledContent("HSTS", value: "Enabled")
                        LabeledContent("HSTS Subdomains", value: (host.hsts_subdomains?.boolValue ?? false) ? "Yes" : "No")
                    }
                    if let http2 = host.http2_support, http2.boolValue {
                        LabeledContent("HTTP/2", value: "Enabled")
                    }
                }
            }

            Section("Features") {
                LabeledContent("Websocket", value: (host.allow_websocket_upgrade?.boolValue ?? false) ? "Enabled" : "Disabled")
                LabeledContent("Block Exploits", value: (host.block_exploits?.boolValue ?? false) ? "Yes" : "No")
                LabeledContent("Caching", value: (host.caching_enabled?.boolValue ?? false) ? "Enabled" : "Disabled")
            }

            if let config = host.advanced_config, !config.isEmpty {
                Section("Advanced Config") {
                    Text(config)
                        .font(.caption.monospaced())
                }
            }

            if let locations = host.locations, !locations.isEmpty {
                Section("Locations") {
                    ForEach(Array(locations.enumerated()), id: \.offset) { _, location in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.path)
                                .font(.callout)
                            Text("\(location.forward_scheme ?? "http")://\(location.forward_host):\(String(location.forward_port))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(host.domain_names.first ?? "Proxy Host")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
