import SwiftUI

struct DeadHostListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            DeadHostListView(client: client)
                .id(host.id)
        }
    }
}
