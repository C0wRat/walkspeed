import SwiftUI
import WalkSpeedCore

/// A ring gauge that shows the current speed against the limit.
struct SpeedGauge: View {
    /// The speed in metres per second, or `nil` when it's unknown.
    var speed: Double?
    /// The limit in metres per second.
    var limit: Double
    var unit: SpeedUnit
    var zone: PaceZone

    /// The ring covers 270°, starting at the bottom left.
    private static let sweep = 0.75
    private static let startAngle = Angle.degrees(135)
    private static let lineWidth: CGFloat = 22
    private static let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = (diameter - Self.lineWidth) / 2
            ZStack {
                arc(to: 1)
                    .stroke(.quaternary, style: Self.strokeStyle)
                arc(to: fraction(of: speed ?? 0))
                    .stroke(zone.tint.gradient, style: Self.strokeStyle)
                limitTick(radius: radius)
                scaleLabel("0", at: Self.startAngle, distance: radius - Self.lineWidth - 10)
                scaleLabel(scaleMaximumText, at: endAngle, distance: radius - Self.lineWidth - 10)
                readout
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.spring(duration: 0.6), value: speed)
        .animation(.easeInOut(duration: 0.3), value: zone)
        .animation(.snappy, value: limit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current speed")
        .accessibilityValue(speed.map { "\(unit.formatted($0)) \(unit.symbol)" } ?? "Unknown")
    }

    private var readout: some View {
        VStack(spacing: 0) {
            Text(speed.map { unit.formatted($0) } ?? "–")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(speed == nil ? .tertiary : .primary)
                .contentTransition(.numericText(value: speed ?? 0))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(unit.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Self.lineWidth * 2)
    }

    /// The top of the scale: one and a half times the limit, rounded up to a
    /// whole number in the display unit.
    private var scaleMaximum: Double {
        let top = (unit.value(fromMetresPerSecond: limit) * 1.5).rounded(.up)
        return unit.metresPerSecond(from: max(top, 1))
    }

    private var scaleMaximumText: String {
        unit.value(fromMetresPerSecond: scaleMaximum).formatted(.number.precision(.fractionLength(0)))
    }

    private var endAngle: Angle {
        Self.startAngle + .degrees(360 * Self.sweep)
    }

    private func fraction(of value: Double) -> Double {
        min(max(value / scaleMaximum, 0), 1)
    }

    private func arc(to fraction: Double) -> some Shape {
        Circle()
            .inset(by: Self.lineWidth / 2)
            .trim(from: 0, to: Self.sweep * fraction)
            .rotation(Self.startAngle)
    }

    /// A notch across the ring where the limit is.
    private func limitTick(radius: CGFloat) -> some View {
        let angle = Self.startAngle + .degrees(360 * Self.sweep * fraction(of: limit))
        return Capsule()
            .fill(.primary)
            .frame(width: 5, height: Self.lineWidth + 14)
            .offset(y: -radius)
            .rotationEffect(angle + .degrees(90))
    }

    private func scaleLabel(_ text: String, at angle: Angle, distance: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .offset(x: distance * cos(angle.radians), y: distance * sin(angle.radians))
    }
}

#Preview {
    SpeedGauge(speed: 1.62, limit: 1.5, unit: .kilometresPerHour, zone: .overLimit)
        .padding(40)
}
