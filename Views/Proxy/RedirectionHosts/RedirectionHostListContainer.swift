import SwiftUI

struct RedirectionHostListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            RedirectionHostListView(client: client)
                .id(host.id)
        }
    }
}
