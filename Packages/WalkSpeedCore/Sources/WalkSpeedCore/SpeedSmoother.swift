import Foundation

/// Smooths noisy GPS speeds by taking the median of the readings from the last
/// few seconds.
///
/// GPS speed jumps around, especially near buildings and trees. A median
/// ignores one-off spikes that would otherwise set off a false alert, and it
/// still follows a real change of pace within about half a window.
public struct SpeedSmoother: Sendable {
    /// How long a reading counts for, in seconds.
    public var window: TimeInterval
    /// Readings with a speed accuracy worse than this, in metres per second,
    /// are ignored.
    public var maxSpeedAccuracy: Double

    /// The smoothed speed in metres per second, or `nil` when no trustworthy
    /// reading arrived within the window.
    public private(set) var speed: Double?

    private var readings: [SpeedSample] = []
    private var latestTimestamp: Date?

    public init(window: TimeInterval = 4, maxSpeedAccuracy: Double = 1.0) {
        self.window = window
        self.maxSpeedAccuracy = maxSpeedAccuracy
    }

    /// Adds a reading and returns the new smoothed speed.
    ///
    /// Readings older than one already seen are ignored. Core Location can
    /// deliver a cached fix late, and it must not count as the current speed.
    @discardableResult
    public mutating func add(_ sample: SpeedSample) -> Double? {
        if let latestTimestamp, sample.timestamp < latestTimestamp {
            return speed
        }
        latestTimestamp = sample.timestamp
        if sample.hasValidSpeed, sample.speedAccuracy <= maxSpeedAccuracy {
            readings.append(sample)
        }
        return advance(to: sample.timestamp)
    }

    /// Drops readings that have fallen out of the window by `date` and
    /// returns the smoothed speed. Call it on a timer, so the speed goes
    /// stale when readings stop arriving.
    @discardableResult
    public mutating func advance(to date: Date) -> Double? {
        readings.removeAll { date.timeIntervalSince($0.timestamp) > window }
        speed = median(of: readings.map(\.speed))
        return speed
    }

    /// Forgets every reading.
    public mutating func reset() {
        readings.removeAll()
        latestTimestamp = nil
        speed = nil
    }

    private func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
