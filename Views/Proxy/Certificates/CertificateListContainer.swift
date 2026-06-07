import SwiftUI

struct CertificateListContainer: View {
    var body: some View {
        NPMHostGate { host, client in
            CertificateListView(client: client)
                .id(host.id)
        }
    }
}
