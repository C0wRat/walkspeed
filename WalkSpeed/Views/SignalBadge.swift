import SwiftUI
import WalkSpeedCore

/// A small pill that shows how good the GPS signal is.
struct SignalBadge: View {
    var signal: SignalQuality

    var body: some View {
        Label(title, systemImage: "location.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: .capsule)
    }

    private var title: LocalizedStringKey {
        switch signal {
        case .unavailable: "No GPS signal"
        case .poor: "Weak GPS"
        case .fair: "Fair GPS"
        case .good: "Good GPS"
        }
    }

    private var color: Color {
        switch signal {
        case .unavailable, .poor: .orange
        case .fair: .secondary
        case .good: .green
        }
    }
}
