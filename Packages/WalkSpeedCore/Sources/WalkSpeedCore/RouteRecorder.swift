import Foundation

/// A point on the route of a walk.
public struct RoutePoint: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    /// Whether you were over the limit when you passed this point.
    public var isOverLimit: Bool

    public init(latitude: Double, longitude: Double, timestamp: Date, isOverLimit: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.isOverLimit = isOverLimit
    }

    /// The great-circle distance to another point in metres.
    public func distance(to other: RoutePoint) -> Double {
        let earthRadius = 6_371_000.0
        let latitude1 = latitude * .pi / 180
        let latitude2 = other.latitude * .pi / 180
        let deltaLatitude = latitude2 - latitude1
        let deltaLongitude = (other.longitude - longitude) * .pi / 180
        let haversine = pow(sin(deltaLatitude / 2), 2)
            + cos(latitude1) * cos(latitude2) * pow(sin(deltaLongitude / 2), 2)
        return 2 * earthRadius * asin(min(1, sqrt(haversine)))
    }
}

/// Builds the route of a walk from location fixes.
///
/// Fixes with a poor position accuracy are dropped, and fixes closer than
/// ``minimumSpacing`` to the last kept point are skipped. That keeps an
/// hour's walk to about a thousand points. A change between under and over
/// the limit is always kept, so the route can be coloured accurately.
public struct RouteRecorder: Sendable {
    /// Fixes less accurate than this, in metres, are dropped.
    public var maxHorizontalAccuracy: Double
    /// The minimum distance between kept points, in metres.
    public var minimumSpacing: Double

    /// The kept points, oldest first.
    public private(set) var points: [RoutePoint] = []
    /// The length of the route in metres.
    public private(set) var distance: Double = 0

    public init(maxHorizontalAccuracy: Double = 25, minimumSpacing: Double = 5) {
        self.maxHorizontalAccuracy = maxHorizontalAccuracy
        self.minimumSpacing = minimumSpacing
    }

    /// Adds a location fix.
    ///
    /// - Parameters:
    ///   - point: Where and when the fix was taken.
    ///   - horizontalAccuracy: The position's uncertainty in metres. A
    ///     negative value means the position is invalid.
    public mutating func add(_ point: RoutePoint, horizontalAccuracy: Double) {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= maxHorizontalAccuracy else { return }
        guard let last = points.last else {
            points.append(point)
            return
        }
        guard point.timestamp >= last.timestamp else { return }
        let step = last.distance(to: point)
        guard step >= minimumSpacing || point.isOverLimit != last.isOverLimit else { return }
        distance += step
        points.append(point)
    }
}

/// A stretch of route that was either all under or all over the limit.
public struct RouteSegment: Equatable, Sendable {
    public var points: [RoutePoint]
    public var isOverLimit: Bool

    public init(points: [RoutePoint], isOverLimit: Bool) {
        self.points = points
        self.isOverLimit = isOverLimit
    }

    /// Splits a route into stretches by whether you were over the limit.
    ///
    /// The line between two points takes the state of the later point, which
    /// is how fast you were going when you got there. Each stretch starts
    /// where the previous one ended, so the drawn line stays connected.
    public static func segments(of route: [RoutePoint]) -> [RouteSegment] {
        guard let first = route.first else { return [] }
        guard route.count > 1 else {
            return [RouteSegment(points: [first], isOverLimit: first.isOverLimit)]
        }
        var segments: [RouteSegment] = []
        var current = RouteSegment(points: [first, route[1]], isOverLimit: route[1].isOverLimit)
        for index in route.indices.dropFirst(2) {
            let point = route[index]
            if point.isOverLimit == current.isOverLimit {
                current.points.append(point)
            } else {
                segments.append(current)
                current = RouteSegment(points: [route[index - 1], point], isOverLimit: point.isOverLimit)
            }
        }
        segments.append(current)
        return segments
    }
}

/// The latitude and longitude range a route covers.
public struct RouteBounds: Equatable, Sendable {
    public var minLatitude: Double
    public var maxLatitude: Double
    public var minLongitude: Double
    public var maxLongitude: Double

    /// The bounds of a route, or `nil` if it has no points.
    public init?(of route: [RoutePoint]) {
        guard let first = route.first else { return nil }
        minLatitude = first.latitude
        maxLatitude = first.latitude
        minLongitude = first.longitude
        maxLongitude = first.longitude
        for point in route.dropFirst() {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            minLongitude = min(minLongitude, point.longitude)
            maxLongitude = max(maxLongitude, point.longitude)
        }
    }

    public var centerLatitude: Double { (minLatitude + maxLatitude) / 2 }
    public var centerLongitude: Double { (minLongitude + maxLongitude) / 2 }
    public var latitudeSpan: Double { maxLatitude - minLatitude }
    public var longitudeSpan: Double { maxLongitude - minLongitude }
}
