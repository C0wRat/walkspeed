import SwiftUI
import WalkSpeedCore

/// Two pills that show which sensors are measuring the speed: GPS and the
/// pedometer.
struct SensorBadges: View {
    var gps: SignalQuality
    var isPedometerActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            badge(gpsTitle, systemImage: "location.fill", color: gpsColor)
            badge(
                isPedometerActive ? "Pedometer" : "No steps",
                systemImage: "figure.walk",
                color: isPedometerActive ? .green : .secondary
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func badge(_ title: LocalizedStringKey, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: .capsule)
    }

    private var gpsTitle: LocalizedStringKey {
        switch gps {
        case .unavailable: "No GPS"
        case .poor: "Weak GPS"
        case .fair: "Fair GPS"
        case .good: "Good GPS"
        }
    }

    /// Missing GPS is only a warning when the pedometer isn't covering for it.
    private var gpsColor: Color {
        switch gps {
        case .unavailable: isPedometerActive ? .secondary : .orange
        case .poor: .orange
        case .fair: .secondary
        case .good: .green
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SensorBadges(gps: .good, isPedometerActive: true)
        SensorBadges(gps: .unavailable, isPedometerActive: true)
        SensorBadges(gps: .unavailable, isPedometerActive: false)
    }
}
