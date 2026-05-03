import SwiftUI

/// The actual scrolling logs list. Pulled out of `ContainerLogsView` per swiftui-pro guidance:
/// extract subviews into structs rather than computed `some View` properties.
struct LogsScrollView: View {
    @Bindable var viewModel: LogsViewModel

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.visibleLines) { line in
                    Text(line.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 1,
                            leading: DesignSystem.Spacing.medium,
                            bottom: 1,
                            trailing: DesignSystem.Spacing.medium
                        ))
                        .id(line.id)
                }
                if !viewModel.isFollowing {
                    Button("Load more") {
                        Task { await viewModel.loadMore() }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .onChange(of: viewModel.visibleLines.count) {
                guard viewModel.isFollowing, let lastID = viewModel.visibleLines.last?.id else { return }
                withAnimation(DesignSystem.Animation.standard) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}
