import SwiftUI

struct ProxyHostListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            ProxyHostListView(client: client)
                .id(host.id)
        }
    }
}
