import Foundation
import Testing
import WalkSpeedCore

@Suite("SpeedTrace")
struct SpeedTraceTests {
    @Test func averagesEachBucket() {
        var trace = SpeedTrace(startDate: date(0), bucketDuration: 5)
        for (second, speed) in [(0.0, 1.0), (2.0, 2.0), (4.9, 3.0), (5.0, 1.5), (9.0, 1.5)] {
            trace.add(speed: speed, at: date(second))
        }
        trace.finish()
        #expect(trace.points == [
            SpeedTrace.Point(offset: 2.5, speed: 2.0),
            SpeedTrace.Point(offset: 7.5, speed: 1.5),
        ])
    }

    @Test func leavesGapsForUnknownSpeeds() {
        var trace = SpeedTrace(startDate: date(0), bucketDuration: 5)
        trace.add(speed: 1.2, at: date(1))
        trace.add(speed: nil, at: date(6))
        trace.add(speed: 1.4, at: date(12))
        trace.finish()
        #expect(trace.points.map(\.offset) == [2.5, 12.5])
    }

    @Test func ignoresSpeedsOlderThanTheCurrentBucket() {
        var trace = SpeedTrace(startDate: date(0), bucketDuration: 5)
        trace.add(speed: 1.2, at: date(11))
        trace.add(speed: 9.0, at: date(3))
        trace.finish()
        #expect(trace.points == [SpeedTrace.Point(offset: 12.5, speed: 1.2)])
    }

    @Test func emptyTraceHasNoPoints() {
        var trace = SpeedTrace(startDate: date(0))
        trace.finish()
        #expect(trace.points.isEmpty)
    }
}
