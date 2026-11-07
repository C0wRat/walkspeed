import Foundation
import SwiftData
import WalkSpeedCore

/// A finished walk, saved with SwiftData.
@Model
final class Walk {
    var startDate: Date
    var endDate: Date
    /// The speed limit during the walk, in metres per second.
    var limit: Double
    /// How far you walked, in metres.
    var distance: Double
    /// How many steps the pedometer counted, if it was available.
    var steps: Int?
    /// The fastest walking speed, in metres per second.
    var topSpeed: Double?
    /// How long you were over the limit, in seconds.
    var timeOverLimit: TimeInterval
    /// How many alerts played.
    var alertCount: Int
    /// How many points the route has, so lists don't have to decode it.
    var routePointCount: Int
    @Attribute(.externalStorage) var routeData: Data
    @Attribute(.externalStorage) var speedTraceData: Data
    /// A rendered map of the route for lists.
    @Attribute(.externalStorage) var thumbnailData: Data?
    /// Whether the thumbnail was drawn for dark mode.
    var thumbnailIsDark = false

    init(summary: WalkSummary, route: [RoutePoint], speedTrace: [SpeedTrace.Point]) {
        startDate = summary.startDate
        endDate = summary.endDate
        limit = summary.limit
        distance = summary.distance
        steps = summary.steps
        topSpeed = summary.topSpeed
        timeOverLimit = summary.timeOverLimit
        alertCount = summary.alertCount
        routePointCount = route.count
        routeData = Self.encode(route)
        speedTraceData = Self.encode(speedTrace)
    }

    /// The walk's totals.
    var summary: WalkSummary {
        WalkSummary(
            startDate: startDate,
            endDate: endDate,
            limit: limit,
            distance: distance,
            steps: steps,
            topSpeed: topSpeed,
            timeOverLimit: timeOverLimit,
            alertCount: alertCount
        )
    }

    /// The route, oldest point first.
    var route: [RoutePoint] {
        Self.decode(routeData) ?? []
    }

    /// The speed over the walk, for the chart.
    var speedTrace: [SpeedTrace.Point] {
        Self.decode(speedTraceData) ?? []
    }

    private static func encode(_ value: some Encodable) -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return (try? encoder.encode(value)) ?? Data()
    }

    private static func decode<Value: Decodable>(_ data: Data) -> Value? {
        try? PropertyListDecoder().decode(Value.self, from: data)
    }
}
