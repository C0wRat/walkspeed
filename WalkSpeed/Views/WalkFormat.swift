import Foundation
import WalkSpeedCore

/// Formats walk statistics for display.
enum WalkFormat {
    /// A duration such as "4:05" or "1:02:30".
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded(.down))
            .formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }

    /// A distance in miles or kilometres, to match the speed unit.
    static func distance(_ metres: Double, unit: SpeedUnit) -> String {
        let length: UnitLength = unit == .milesPerHour ? .miles : .kilometers
        return Measurement(value: metres, unit: UnitLength.meters)
            .converted(to: length)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2))))
    }

    /// A speed with its unit, such as "3.4 mph", or a dash when unknown.
    static func speed(_ speed: Double?, unit: SpeedUnit) -> String {
        guard let speed else { return "–" }
        return "\(unit.formatted(speed)) \(unit.symbol)"
    }
}
