import Foundation
import Testing
import WalkSpeedCore

@Suite("RouteRecorder")
struct RouteRecorderTests {
    /// About 11.1 m per 0.0001° of latitude.
    let metresPerTenThousandthDegree = 11.12

    @Test func measuresGreatCircleDistance() {
        // One degree of latitude is about 111.2 km.
        let a = point(latitude: 51, longitude: 0)
        let b = point(latitude: 52, longitude: 0)
        #expect(abs(a.distance(to: b) - 111_195) < 10)
        #expect(a.distance(to: a) == 0)
    }

    @Test func dropsInaccurateOrInvalidFixes() {
        var recorder = RouteRecorder(maxHorizontalAccuracy: 25)
        recorder.add(point(latitude: 51.5), horizontalAccuracy: 65)
        recorder.add(point(latitude: 51.5), horizontalAccuracy: -1)
        #expect(recorder.points.isEmpty)
        recorder.add(point(latitude: 51.5), horizontalAccuracy: 10)
        #expect(recorder.points.count == 1)
    }

    @Test func skipsFixesTooCloseToTheLastPoint() {
        var recorder = RouteRecorder(minimumSpacing: 5)
        recorder.add(point(latitude: 51.5, second: 0), horizontalAccuracy: 5)
        recorder.add(point(latitude: 51.500_02, second: 1), horizontalAccuracy: 5) // ~2 m
        recorder.add(point(latitude: 51.500_1, second: 2), horizontalAccuracy: 5) // ~11 m
        #expect(recorder.points.count == 2)
        #expect(abs(recorder.distance - metresPerTenThousandthDegree) < 0.1)
    }

    @Test func keepsAChangeOfLimitStateEvenWhenClose() {
        var recorder = RouteRecorder(minimumSpacing: 5)
        recorder.add(point(latitude: 51.5, second: 0), horizontalAccuracy: 5)
        recorder.add(point(latitude: 51.500_01, second: 1, isOverLimit: true), horizontalAccuracy: 5)
        #expect(recorder.points.map(\.isOverLimit) == [false, true])
    }

    @Test func accumulatesDistanceAlongTheRoute() {
        var recorder = RouteRecorder()
        for step in 0...10 {
            recorder.add(point(latitude: 51.5 + Double(step) * 0.0001, second: Double(step)), horizontalAccuracy: 5)
        }
        #expect(recorder.points.count == 11)
        #expect(abs(recorder.distance - 10 * metresPerTenThousandthDegree) < 1)
    }

    @Test func ignoresFixesOlderThanTheLastPoint() {
        var recorder = RouteRecorder()
        recorder.add(point(latitude: 51.5, second: 10), horizontalAccuracy: 5)
        recorder.add(point(latitude: 51.501, second: 5), horizontalAccuracy: 5)
        #expect(recorder.points.count == 1)
    }
}

@Suite("RouteSegment")
struct RouteSegmentTests {
    @Test func emptyRouteHasNoSegments() {
        #expect(RouteSegment.segments(of: []).isEmpty)
    }

    @Test func singlePointMakesOneSegment() {
        let route = [point(latitude: 51.5)]
        #expect(RouteSegment.segments(of: route) == [RouteSegment(points: route, isOverLimit: false)])
    }

    @Test func splitsAtChangesAndStaysConnected() {
        let states = [false, false, true, true, false]
        let route = states.enumerated().map { index, over in
            point(latitude: 51.5 + Double(index) * 0.001, second: Double(index), isOverLimit: over)
        }
        let segments = RouteSegment.segments(of: route)
        #expect(segments.map(\.isOverLimit) == [false, true, false])
        #expect(segments[0].points == Array(route[0...1]))
        #expect(segments[1].points == Array(route[1...3]))
        #expect(segments[2].points == Array(route[3...4]))
    }

    @Test func lineTakesTheStateOfTheLaterPoint() {
        let route = [point(latitude: 51.5, isOverLimit: true), point(latitude: 51.501, second: 1)]
        #expect(RouteSegment.segments(of: route).map(\.isOverLimit) == [false])
    }
}

@Suite("RouteBounds")
struct RouteBoundsTests {
    @Test func coversEveryPoint() throws {
        let route = [
            point(latitude: 51.50, longitude: -0.17),
            point(latitude: 51.52, longitude: -0.15),
            point(latitude: 51.51, longitude: -0.19),
        ]
        let bounds = try #require(RouteBounds(of: route))
        #expect(bounds.minLatitude == 51.50)
        #expect(bounds.maxLatitude == 51.52)
        #expect(bounds.minLongitude == -0.19)
        #expect(bounds.maxLongitude == -0.15)
        #expect(isClose(bounds.centerLatitude, 51.51))
        #expect(isClose(bounds.longitudeSpan, 0.04))
    }

    @Test func emptyRouteHasNoBounds() {
        #expect(RouteBounds(of: []) == nil)
    }
}

func point(latitude: Double, longitude: Double = -0.17, second: TimeInterval = 0, isOverLimit: Bool = false) -> RoutePoint {
    RoutePoint(latitude: latitude, longitude: longitude, timestamp: date(second), isOverLimit: isOverLimit)
}
