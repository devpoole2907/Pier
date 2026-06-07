import SwiftUI

enum NPMActionState: Sendable {
    case enabling
    case disabling
    case deleting
    case saving
    case renewing

    var displayName: String {
        switch self {
        case .enabling: "Enabling"
        case .disabling: "Disabling"
        case .deleting: "Deleting"
        case .saving: "Saving"
        case .renewing: "Renewing"
        }
    }

    var color: Color {
        switch self {
        case .enabling: .green
        case .disabling: .orange
        case .deleting: .red
        case .saving: .blue
        case .renewing: .green
        }
    }

    var symbolName: String {
        switch self {
        case .enabling: "play.circle.fill"
        case .disabling: "stop.circle.fill"
        case .deleting: "trash.circle.fill"
        case .saving: "arrow.down.doc.fill"
        case .renewing: "arrow.clockwise.circle.fill"
        }
    }
}
