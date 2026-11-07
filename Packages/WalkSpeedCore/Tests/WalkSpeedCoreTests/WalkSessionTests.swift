import Foundation
import Testing
import WalkSpeedCore

@Suite("WalkSession")
struct WalkSessionTests {
    @Test func startsEmpty() {
        let session = WalkSession(startDate: date(0))
        #expect(session.timeOverLimit == 0)
        #expect(session.topSpeed == nil)
        #expect(session.alertCount == 0)
        #expect(session.duration(at: date(90)) == 90)
    }

    @Test func countsOnlyTheTimeSpentOverTheLimit() {
        var session = WalkSession(startDate: date(0))
        let zones: [PaceZone] = [.comfortable, .overLimit, .overLimit, .overLimit, .nearLimit, .comfortable]
        for (second, zone) in zones.enumerated() {
            session.record(speed: 1.4, zone: zone, at: date(Double(second)))
        }
        // Over the limit from 1 s until the reading at 4 s.
        #expect(session.timeOverLimit == 3)
        #expect(isClose(session.fractionOverLimit(at: date(6)), 0.5))
    }

    @Test func skipsGapsInTheSignal() {
        var session = WalkSession(startDate: date(0))
        session.record(speed: 1.6, zone: .overLimit, at: date(0))
        session.record(speed: 1.6, zone: .overLimit, at: date(30))
        session.record(speed: 1.6, zone: .overLimit, at: date(31))
        #expect(session.timeOverLimit == 1)
    }

    @Test func tracksTheTopWalkingSpeed() {
        var session = WalkSession(startDate: date(0))
        session.record(speed: 1.3, zone: .comfortable, at: date(0))
        session.record(speed: 1.7, zone: .overLimit, at: date(1))
        session.record(speed: 9.0, zone: .vehicle, at: date(2))
        session.record(speed: 1.2, zone: .comfortable, at: date(3))
        #expect(session.topSpeed == 1.7)
    }

    @Test func countsAlerts() {
        var session = WalkSession(startDate: date(0))
        session.recordAlert()
        session.recordAlert()
        #expect(session.alertCount == 2)
    }

    @Test func fractionIsZeroAtTheStart() {
        let session = WalkSession(startDate: date(0))
        #expect(session.fractionOverLimit(at: date(0)) == 0)
    }
}
