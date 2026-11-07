import Foundation
import Testing
import WalkSpeedCore

@Suite("WalkSummary")
struct WalkSummaryTests {
    @Test func prefersTheGPSRouteForDistanceOutdoors() {
        let summary = makeSummary(routeDistance: 800, pedometerDistance: 760)
        #expect(summary.distance == 800)
    }

    @Test func usesThePedometerDistanceIndoors() {
        let summary = makeSummary(routeDistance: 12, pedometerDistance: 240)
        #expect(summary.distance == 240)
    }

    @Test func fallsBackToTheShortRouteWithoutAPedometer() {
        let summary = makeSummary(routeDistance: 12, pedometerDistance: nil)
        #expect(summary.distance == 12)
    }

    @Test func derivesDurationAverageAndShareOverTheLimit() throws {
        // 600 s walk, 840 m, 90 s over the limit.
        let summary = makeSummary(routeDistance: 840, pedometerDistance: nil, timeOverLimit: 90)
        #expect(summary.duration == 600)
        #expect(isClose(try #require(summary.averageSpeed), 1.4))
        #expect(isClose(summary.fractionOverLimit, 0.15))
    }

    @Test func hasNoAverageWithoutDistance() {
        #expect(makeSummary(routeDistance: 0, pedometerDistance: nil).averageSpeed == nil)
    }

    @Test func carriesTheSessionTotals() {
        var session = WalkSession(startDate: date(0))
        session.record(speed: 1.7, zone: .overLimit, at: date(1))
        session.recordAlert()
        let summary = WalkSummary(
            session: session, endDate: date(60), limit: 1.5,
            routeDistance: 100, pedometerDistance: nil, steps: 140
        )
        #expect(summary.topSpeed == 1.7)
        #expect(summary.alertCount == 1)
        #expect(summary.steps == 140)
        #expect(summary.limit == 1.5)
    }

    private func makeSummary(routeDistance: Double, pedometerDistance: Double?, timeOverLimit: TimeInterval = 0) -> WalkSummary {
        // One reading a second, like the sensors, over the limit at first.
        var session = WalkSession(startDate: date(0))
        for second in stride(from: 0.0, through: timeOverLimit, by: 1) {
            let isOver = second < timeOverLimit
            session.record(speed: isOver ? 1.7 : 1.2, zone: isOver ? .overLimit : .comfortable, at: date(second))
        }
        return WalkSummary(
            session: session, endDate: date(600), limit: 1.5,
            routeDistance: routeDistance, pedometerDistance: pedometerDistance, steps: nil
        )
    }
}
