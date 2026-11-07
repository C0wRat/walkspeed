import Foundation

/// A unit for showing walking speed.
///
/// WalkSpeed stores and compares every speed in metres per second, the unit
/// Core Location reports. A `SpeedUnit` only matters at the edges: when a
/// speed is shown or a limit is chosen.
public enum SpeedUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case kilometresPerHour = "kmh"
    case milesPerHour = "mph"

    public var id: Self { self }

    /// The label shown after a value, such as "km/h".
    public var symbol: String {
        switch self {
        case .kilometresPerHour: "km/h"
        case .milesPerHour: "mph"
        }
    }

    /// How many metres per second one of this unit is.
    public var metresPerSecond: Double {
        switch self {
        case .kilometresPerHour: 1_000 / 3_600
        case .milesPerHour: 1_609.344 / 3_600
        }
    }

    /// Converts a speed in metres per second into this unit.
    public func value(fromMetresPerSecond speed: Double) -> Double {
        speed / metresPerSecond
    }

    /// Converts a value in this unit into metres per second.
    public func metresPerSecond(from value: Double) -> Double {
        value * metresPerSecond
    }

    /// The amount the limit's − and + buttons change it by, in this unit.
    public var limitStep: Double { 0.1 }

    /// The limits the app offers, in this unit.
    public var limitRange: ClosedRange<Double> {
        switch self {
        case .kilometresPerHour: 2.0...12.0
        case .milesPerHour: 1.2...7.5
        }
    }

    /// Moves a limit by a number of steps of this unit.
    ///
    /// The limit is rounded to the nearest step first, so a limit set in
    /// another unit snaps onto this unit's grid. For example, 1.5 m/s shows
    /// as 3.4 mph, and one step up gives exactly 3.5 mph. The result is
    /// clamped to ``limitRange``.
    ///
    /// - Parameters:
    ///   - limit: The current limit in metres per second.
    ///   - steps: How many steps to move by. Negative values move down.
    /// - Returns: The new limit in metres per second.
    public func steppedLimit(_ limit: Double, by steps: Int) -> Double {
        let current = (value(fromMetresPerSecond: limit) / limitStep).rounded() * limitStep
        let moved = current + Double(steps) * limitStep
        let clamped = min(max(moved, limitRange.lowerBound), limitRange.upperBound)
        return metresPerSecond(from: clamped)
    }

    /// Formats a speed given in metres per second as a number in this unit,
    /// such as "5.4".
    public func formatted(_ speed: Double, locale: Locale = .current) -> String {
        value(fromMetresPerSecond: speed)
            .formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    /// The unit a region usually uses for walking speed. That's miles per hour
    /// in the US and the UK, and kilometres per hour everywhere else.
    public static func preferred(for locale: Locale = .current) -> SpeedUnit {
        switch locale.measurementSystem {
        case .us, .uk: .milesPerHour
        default: .kilometresPerHour
        }
    }
}
