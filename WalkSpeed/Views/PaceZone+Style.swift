import SwiftUI
import WalkSpeedCore

extension PaceZone {
    /// The colour that stands for the zone.
    var tint: Color {
        switch self {
        case .unknown, .vehicle: .gray
        case .comfortable: .accentColor
        case .nearLimit: .orange
        case .overLimit: .red
        }
    }
}
