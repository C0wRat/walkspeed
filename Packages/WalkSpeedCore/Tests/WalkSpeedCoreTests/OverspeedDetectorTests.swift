import Foundation
import Testing
import WalkSpeedCore

@Suite("OverspeedDetector")
struct OverspeedDetectorTests {
    /// A 1.5 m/s limit, a 2 s delay and a 5 s repeat.
    let configuration = AlertConfiguration(limit: 1.5, alertDelay: 2, repeatInterval: 5)

    @Test func staysQuietUnderTheLimit() {
        #expect(beeps(for: Array(repeating: 1.4, count: 30)).isEmpty)
    }

    @Test func waitsForTheAlertDelayBeforeTheFirstBeep() {
        let result = beeps(for: Array(repeating: 1.6, count: 3))
        #expect(result == [Beep(second: 2, level: .gentle)])
    }

    @Test func beepsImmediatelyWithoutADelay() {
        var configuration = configuration
        configuration.alertDelay = 0
        #expect(beeps(for: [1.6], configuration: configuration) == [Beep(second: 0, level: .gentle)])
    }

    @Test func repeatsWhileOverTheLimit() {
        let result = beeps(for: Array(repeating: 1.6, count: 13))
        #expect(result.map(\.second) == [2, 7, 12])
    }

    @Test func toleratesLocationUpdateJitter() {
        var detector = OverspeedDetector(configuration: configuration)
        let times: [TimeInterval] = [0, 1, 2, 3.1, 4.0, 5.2, 6.1, 6.9, 8.0]
        let alertTimes = times.filter { detector.update(speed: 1.6, at: date($0)) != nil }
        // The repeat fires at 6.9 s, 4.9 s after the first beep, not at 8 s.
        #expect(alertTimes == [2, 6.9])
    }

    @Test func ignoresABlipShorterThanTheDelay() {
        #expect(beeps(for: [1.4, 1.6, 1.4, 1.4, 1.4]).isEmpty)
    }

    @Test func hoveringJustUnderTheLimitKeepsTheEpisodeGoing() {
        // Over long enough to beep, dip just under the limit (within the
        // hysteresis), then go back over: it beeps again without a new delay.
        let speeds = [1.6, 1.6, 1.6] + Array(repeating: 1.45, count: 5) + [1.6]
        #expect(beeps(for: speeds).map(\.second) == [2, 8])
    }

    @Test func droppingClearlyUnderTheLimitEndsTheEpisode() {
        // After dropping well under, going over again waits for the delay.
        let speeds = [1.6, 1.6, 1.6] + Array(repeating: 1.2, count: 5) + [1.6, 1.6, 1.6]
        #expect(beeps(for: speeds).map(\.second) == [2, 10])
    }

    @Test func neverBeepsAtVehicleSpeeds() {
        #expect(beeps(for: Array(repeating: 8.0, count: 20)).isEmpty)
    }

    @Test func vehicleSpeedsEndTheEpisode() {
        let speeds = [1.6, 1.6, 1.6, 8.0, 1.6, 1.6, 1.6]
        #expect(beeps(for: speeds).map(\.second) == [2, 6])
    }

    @Test func unknownSpeedEndsTheEpisode() {
        var detector = OverspeedDetector(configuration: configuration)
        for second in 0...2 {
            _ = detector.update(speed: 1.6, at: date(Double(second)))
        }
        #expect(detector.isAlerting)
        _ = detector.update(speed: nil, at: date(3))
        #expect(!detector.isAlerting)
    }

    @Test(arguments: [
        (1.55, AlertLevel.gentle),
        (1.7, .firm),
        (1.8, .firm),
        (1.95, .urgent),
        (2.5, .urgent),
    ])
    func levelGrowsWithTheExcess(speed: Double, expected: AlertLevel) {
        #expect(configuration.level(for: speed) == expected)
    }

    @Test func raisingTheLimitMidEpisodeStopsTheBeeps() {
        var detector = OverspeedDetector(configuration: configuration)
        var alerts: [Int] = []
        for second in 0..<15 {
            if second == 5 {
                detector.configuration.limit = 2.0
            }
            if detector.update(speed: 1.6, at: date(Double(second))) != nil {
                alerts.append(second)
            }
        }
        #expect(alerts == [2])
    }

    @Test func resetEndsTheEpisode() {
        var detector = OverspeedDetector(configuration: configuration)
        for second in 0...2 {
            _ = detector.update(speed: 1.6, at: date(Double(second)))
        }
        detector.reset()
        #expect(!detector.isAlerting)
        #expect(detector.update(speed: 1.6, at: date(3)) == nil)
    }

    private struct Beep: Equatable {
        let second: Int
        let level: AlertLevel
    }

    /// Feeds one speed per second, starting at 0 s, and returns the beeps.
    private func beeps(for speeds: [Double?], configuration: AlertConfiguration? = nil) -> [Beep] {
        var detector = OverspeedDetector(configuration: configuration ?? self.configuration)
        return speeds.enumerated().compactMap { second, speed in
            detector.update(speed: speed, at: date(Double(second))).map { Beep(second: second, level: $0) }
        }
    }
}

@Suite("PaceZone")
struct PaceZoneTests {
    let configuration = AlertConfiguration(limit: 1.5)

    @Test(arguments: [
        (nil, PaceZone.unknown),
        (1.0, .comfortable),
        (1.4, .nearLimit),
        (1.5, .nearLimit),
        (1.51, .overLimit),
        (6.0, .vehicle),
    ] as [(Double?, PaceZone)])
    func classifiesSpeed(speed: Double?, expected: PaceZone) {
        #expect(PaceZone(speed: speed, configuration: configuration) == expected)
    }
}
