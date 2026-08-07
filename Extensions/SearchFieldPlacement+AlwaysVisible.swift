import SwiftUI

extension SearchFieldPlacement {
    /// Keeps search visible in the navigation drawer on iOS. macOS has no drawer placement, so
    /// its toolbar placement provides the equivalent persistent search field.
    static var alwaysVisible: SearchFieldPlacement {
        #if os(iOS)
        .navigationBarDrawer(displayMode: .always)
        #else
        .toolbar
        #endif
    }
}
