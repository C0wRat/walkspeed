import Foundation

/// Running totals for one monitoring session.
public struct WalkSession: Equatable, Sendable {
    /// When monitoring started.
    public let startDate: Date
    /// How long the speed was over the limit, in seconds.
    public private(set) var timeOverLimit: TimeInterval = 0
    /// The fastest walking speed seen, in metres per second. Vehicle speeds
    /// don't count.
    public private(set) var topSpeed: Double?
    /// How many alerts played.
    public private(set) var alertCount = 0

    private var lastReadingDate: Date?
    private var lastReadingWasOverLimit = false

    /// Readings further apart than this, in seconds, are treated as a gap
    /// in the signal. A gap doesn't count towards the time over the limit.
    public static let maxReadingGap: TimeInterval = 10

    public init(startDate: Date) {
        self.startDate = startDate
    }

    /// How long the session has been running at `date`.
    public func duration(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startDate))
    }

    /// The share of the session spent over the limit, from 0 to 1.
    public func fractionOverLimit(at date: Date) -> Double {
        let duration = duration(at: date)
        guard duration > 0 else { return 0 }
        return min(1, timeOverLimit / duration)
    }

    /// Adds a smoothed reading.
    public mutating func record(speed: Double?, zone: PaceZone, at date: Date) {
        if let lastReadingDate, lastReadingWasOverLimit {
            let interval = date.timeIntervalSince(lastReadingDate)
            if interval > 0, interval <= Self.maxReadingGap {
                timeOverLimit += interval
            }
        }
        if let speed, zone != .vehicle, zone != .unknown {
            topSpeed = max(topSpeed ?? speed, speed)
        }
        lastReadingDate = date
        lastReadingWasOverLimit = zone == .overLimit
    }

    /// Counts an alert that played.
    public mutating func recordAlert() {
        alertCount += 1
    }
}
