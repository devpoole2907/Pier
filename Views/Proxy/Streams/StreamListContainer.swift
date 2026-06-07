import SwiftUI

struct StreamListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            StreamListView(client: client)
                .id(host.id)
        }
    }
}
