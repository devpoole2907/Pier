import SwiftUI

struct NoProxyConfiguredView: View {
    @Environment(NPMHostManager.self) private var npmHostManager

    var body: some View {
        ContentUnavailableView {
            Label("No NPM host", systemImage: "point.3.connected.trianglepath.dotted")
        } description: {
            Text("Add an Nginx Proxy Manager instance to manage your proxy hosts.")
        } actions: {
            Button("Add Host", systemImage: "plus") {
                npmHostManager.isPresentingHostEditor = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
