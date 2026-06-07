import SwiftUI

struct AccessListListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            AccessListListView(client: client)
                .id(host.id)
        }
    }
}
