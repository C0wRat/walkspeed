import Foundation

/// The sensors a speed estimate is based on.
public enum SpeedSource: Sendable {
    /// GPS alone.
    case gps
    /// The pedometer alone, for example indoors.
    case pedometer
    /// GPS and the pedometer, each weighted by how far it can be trusted.
    case gpsAndPedometer
}

/// A walking speed and the sensors it came from.
public struct SpeedEstimate: Equatable, Sendable {
    /// The speed in metres per second.
    public var speed: Double
    public var source: SpeedSource

    public init(speed: Double, source: SpeedSource) {
        self.speed = speed
        self.source = source
    }
}

/// Combines GPS speed with the pedometer's pace into one walking speed.
///
/// GPS measures speed directly and is accurate under open sky, but it's noisy
/// near buildings and useless indoors. The pedometer in the motion coprocessor
/// works anywhere, but its speed relies on an estimated stride length. When
/// both are available, each is weighted by the inverse of its variance. A
/// strong GPS signal dominates, and a weak one defers to the pedometer.
public struct SpeedEstimator: Sendable {
    /// The assumed uncertainty of pedometer speeds, in metres per second.
    public var pedometerUncertainty: Double
    /// How long a pedometer reading counts for, in seconds. The pedometer
    /// stops reporting when you stop walking, so its last pace mustn't linger.
    public var pedometerMaxAge: TimeInterval

    /// The current estimate, or `nil` when no sensor has a usable reading.
    public private(set) var estimate: SpeedEstimate?
    /// The latest pedometer speed in metres per second, or `nil` when it's
    /// stale.
    public private(set) var pedometerSpeed: Double?

    /// The median speed accuracy of the recent GPS readings in metres per
    /// second, or `nil` when there are none.
    public var gpsAccuracy: Double? { gps.accuracy }

    private var gps: SpeedSmoother
    private var lastPedometerReading: (speed: Double, timestamp: Date)?

    /// GPS accuracies are floored at this, so that one overconfident reading
    /// can't shut the pedometer out completely.
    private static let minimumGPSAccuracy = 0.05

    public init(
        gpsWindow: TimeInterval = 4,
        maxGPSAccuracy: Double = 1.0,
        pedometerUncertainty: Double = 0.5,
        pedometerMaxAge: TimeInterval = 8
    ) {
        gps = SpeedSmoother(window: gpsWindow, maxSpeedAccuracy: maxGPSAccuracy)
        self.pedometerUncertainty = pedometerUncertainty
        self.pedometerMaxAge = pedometerMaxAge
    }

    /// Adds a GPS reading and returns the new estimate.
    @discardableResult
    public mutating func addGPS(_ sample: SpeedSample) -> SpeedEstimate? {
        gps.add(sample)
        return update(at: sample.timestamp)
    }

    /// Adds a pedometer speed and returns the new estimate. Readings older
    /// than one already seen are ignored.
    ///
    /// - Parameters:
    ///   - speed: The walking speed in metres per second.
    ///   - date: When the reading arrived.
    @discardableResult
    public mutating func addPedometer(speed: Double, at date: Date) -> SpeedEstimate? {
        if let lastPedometerReading, date < lastPedometerReading.timestamp {
            return estimate
        }
        if speed >= 0 {
            lastPedometerReading = (speed, date)
        }
        return update(at: date)
    }

    /// Drops readings that have gone stale by `date` and returns the
    /// estimate. Call it on a timer, so the estimate expires when the sensors
    /// go quiet.
    @discardableResult
    public mutating func advance(to date: Date) -> SpeedEstimate? {
        update(at: date)
    }

    /// Forgets every reading.
    public mutating func reset() {
        gps.reset()
        lastPedometerReading = nil
        pedometerSpeed = nil
        estimate = nil
    }

    private mutating func update(at date: Date) -> SpeedEstimate? {
        let gpsSpeed = gps.advance(to: date)
        pedometerSpeed = lastPedometerReading.flatMap { reading in
            date.timeIntervalSince(reading.timestamp) <= pedometerMaxAge ? reading.speed : nil
        }

        switch (gpsSpeed, pedometerSpeed) {
        case let (gpsSpeed?, pedometerSpeed?):
            let gpsWeight = 1 / pow(max(gps.accuracy ?? 1, Self.minimumGPSAccuracy), 2)
            let pedometerWeight = 1 / pow(pedometerUncertainty, 2)
            let speed = (gpsSpeed * gpsWeight + pedometerSpeed * pedometerWeight) / (gpsWeight + pedometerWeight)
            estimate = SpeedEstimate(speed: speed, source: .gpsAndPedometer)
        case let (gpsSpeed?, nil):
            estimate = SpeedEstimate(speed: gpsSpeed, source: .gps)
        case let (nil, pedometerSpeed?):
            estimate = SpeedEstimate(speed: pedometerSpeed, source: .pedometer)
        case (nil, nil):
            estimate = nil
        }
        return estimate
    }
}
