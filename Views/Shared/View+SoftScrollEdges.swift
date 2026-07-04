import SwiftUI

extension View {
    /// Applies the iOS 26 soft scroll-edge effect to a primary scrollable view (List/ScrollView/Form),
    /// so content fades under the navigation bar and toolbar instead of hard-clipping.
    func softScrollEdges() -> some View {
        scrollEdgeEffectStyle(.soft, for: .all)
    }
}
