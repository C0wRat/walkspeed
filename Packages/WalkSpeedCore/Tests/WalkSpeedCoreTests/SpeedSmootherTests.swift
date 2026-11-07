import Foundation
import Testing
import WalkSpeedCore

@Suite("SpeedSmoother")
struct SpeedSmootherTests {
    @Test func hasNoSpeedUntilAReadingArrives() {
        let smoother = SpeedSmoother()
        #expect(smoother.speed == nil)
    }

    @Test func ignoresReadingsWithoutASpeed() {
        var smoother = SpeedSmoother()
        #expect(smoother.add(sample(at: 0, speed: -1)) == nil)
        #expect(smoother.add(sample(at: 1, speed: 1.4, accuracy: -1)) == nil)
    }

    @Test func ignoresInaccurateReadings() {
        var smoother = SpeedSmoother(maxSpeedAccuracy: 1.0)
        smoother.add(sample(at: 0, speed: 1.4, accuracy: 0.3))
        #expect(smoother.add(sample(at: 1, speed: 4.0, accuracy: 2.5)) == 1.4)
    }

    @Test func rejectsASingleSpike() {
        var smoother = SpeedSmoother(window: 4)
        for (second, speed) in [1.3, 1.3, 3.2, 1.3, 1.3].enumerated() {
            smoother.add(sample(at: Double(second), speed: speed))
        }
        #expect(smoother.speed == 1.3)
    }

    @Test func averagesTheMiddleTwoReadingsOfAnEvenCount() {
        var smoother = SpeedSmoother(window: 10)
        for (second, speed) in [1.0, 1.2, 1.4, 1.6].enumerated() {
            smoother.add(sample(at: Double(second), speed: speed))
        }
        #expect(isClose(smoother.speed ?? 0, 1.3))
    }

    @Test func followsARealChangeOfPace() {
        var smoother = SpeedSmoother(window: 4)
        for second in 0..<5 {
            smoother.add(sample(at: Double(second), speed: 1.2))
        }
        // Speed up to 1.8 m/s. After three of the five readings in the
        // window are fast, the median follows.
        smoother.add(sample(at: 5, speed: 1.8))
        smoother.add(sample(at: 6, speed: 1.8))
        #expect(smoother.speed == 1.2)
        smoother.add(sample(at: 7, speed: 1.8))
        #expect(smoother.speed == 1.8)
    }

    @Test func dropsReadingsThatLeaveTheWindow() {
        var smoother = SpeedSmoother(window: 4)
        smoother.add(sample(at: 0, speed: 2.0))
        smoother.add(sample(at: 5, speed: 1.0))
        #expect(smoother.speed == 1.0)
    }

    @Test func goesStaleWhenReadingsStop() {
        var smoother = SpeedSmoother(window: 4)
        smoother.add(sample(at: 0, speed: 1.4))
        #expect(smoother.advance(to: date(4)) == 1.4)
        #expect(smoother.advance(to: date(4.5)) == nil)
    }

    @Test func ignoresReadingsOlderThanOnesAlreadySeen() {
        var smoother = SpeedSmoother(window: 10)
        smoother.add(sample(at: 5, speed: 1.4))
        smoother.add(sample(at: 1, speed: 3.0))
        #expect(smoother.speed == 1.4)
    }

    @Test func reportsTheMedianAccuracyOfTheWindow() {
        var smoother = SpeedSmoother(window: 10)
        #expect(smoother.accuracy == nil)
        smoother.add(sample(at: 0, speed: 1.4, accuracy: 0.2))
        smoother.add(sample(at: 1, speed: 1.4, accuracy: 0.9))
        smoother.add(sample(at: 2, speed: 1.4, accuracy: 0.4))
        #expect(smoother.accuracy == 0.4)
        smoother.advance(to: date(20))
        #expect(smoother.accuracy == nil)
    }

    @Test func resetForgetsEverything() {
        var smoother = SpeedSmoother()
        smoother.add(sample(at: 5, speed: 1.4))
        smoother.reset()
        #expect(smoother.speed == nil)
        #expect(smoother.accuracy == nil)
        // An earlier timestamp is accepted again after a reset.
        #expect(smoother.add(sample(at: 1, speed: 1.1)) == 1.1)
    }
}

@Suite("SignalQuality")
struct SignalQualityTests {
    @Test(arguments: [
        (-1.0, SignalQuality.unavailable),
        (0.2, .good),
        (0.5, .good),
        (0.8, .fair),
        (1.0, .fair),
        (3.0, .poor),
    ])
    func gradesSpeedAccuracy(accuracy: Double, expected: SignalQuality) {
        #expect(SignalQuality(speedAccuracy: accuracy) == expected)
    }
}

func date(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSinceReferenceDate: 800_000_000 + seconds)
}

func sample(at seconds: TimeInterval, speed: Double, accuracy: Double = 0.3) -> SpeedSample {
    SpeedSample(timestamp: date(seconds), speed: speed, speedAccuracy: accuracy)
}
