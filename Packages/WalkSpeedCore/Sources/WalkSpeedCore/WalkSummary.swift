import Foundation

/// The totals of a finished walk.
public struct WalkSummary: Codable, Equatable, Sendable {
    public var startDate: Date
    public var endDate: Date
    /// The speed limit during the walk, in metres per second.
    public var limit: Double
    /// How far you walked, in metres.
    public var distance: Double
    /// How many steps the pedometer counted, if it was available.
    public var steps: Int?
    /// The fastest walking speed, in metres per second.
    public var topSpeed: Double?
    /// How long you were over the limit, in seconds.
    public var timeOverLimit: TimeInterval
    /// How many alerts played.
    public var alertCount: Int

    /// A GPS route at least this long, in metres, is trusted for the
    /// distance. Shorter ones mean the walk was mostly indoors, where the
    /// pedometer's distance is better.
    public static let minimumRouteDistance = 50.0

    public init(
        startDate: Date,
        endDate: Date,
        limit: Double,
        distance: Double,
        steps: Int?,
        topSpeed: Double?,
        timeOverLimit: TimeInterval,
        alertCount: Int
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
        self.distance = distance
        self.steps = steps
        self.topSpeed = topSpeed
        self.timeOverLimit = timeOverLimit
        self.alertCount = alertCount
    }

    /// Summarizes a session.
    ///
    /// - Parameters:
    ///   - session: The session's running totals.
    ///   - endDate: When monitoring stopped.
    ///   - limit: The speed limit at the end, in metres per second.
    ///   - routeDistance: The length of the GPS route, in metres.
    ///   - pedometerDistance: The pedometer's distance, in metres, if any.
    ///   - steps: The pedometer's step count, if any.
    public init(
        session: WalkSession,
        endDate: Date,
        limit: Double,
        routeDistance: Double,
        pedometerDistance: Double?,
        steps: Int?
    ) {
        let distance = routeDistance >= Self.minimumRouteDistance
            ? routeDistance
            : max(routeDistance, pedometerDistance ?? 0)
        self.init(
            startDate: session.startDate,
            endDate: endDate,
            limit: limit,
            distance: distance,
            steps: steps,
            topSpeed: session.topSpeed,
            timeOverLimit: session.timeOverLimit,
            alertCount: session.alertCount
        )
    }

    /// How long the walk lasted, in seconds.
    public var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    /// The average speed over the whole walk in metres per second, or `nil`
    /// if you didn't go anywhere.
    public var averageSpeed: Double? {
        guard duration > 0, distance > 0 else { return nil }
        return distance / duration
    }

    /// The share of the walk spent over the limit, from 0 to 1.
    public var fractionOverLimit: Double {
        guard duration > 0 else { return 0 }
        return min(1, timeOverLimit / duration)
    }
}
