import Foundation
import Testing
import WalkSpeedCore

@Suite("SpeedEstimator")
struct SpeedEstimatorTests {
    @Test func hasNoEstimateWithoutReadings() {
        var estimator = SpeedEstimator()
        #expect(estimator.estimate == nil)
        #expect(estimator.advance(to: date(10)) == nil)
    }

    @Test func usesGPSAloneOutdoorsWithoutSteps() {
        var estimator = SpeedEstimator()
        let estimate = estimator.addGPS(sample(at: 0, speed: 1.4, accuracy: 0.3))
        #expect(estimate == SpeedEstimate(speed: 1.4, source: .gps))
    }

    @Test func usesThePedometerAloneIndoors() {
        var estimator = SpeedEstimator()
        let estimate = estimator.addPedometer(speed: 1.3, at: date(0))
        #expect(estimate == SpeedEstimate(speed: 1.3, source: .pedometer))
    }

    @Test func strongGPSDominatesTheBlend() throws {
        var estimator = SpeedEstimator(pedometerUncertainty: 0.5)
        estimator.addPedometer(speed: 1.2, at: date(0))
        estimator.addGPS(sample(at: 0.5, speed: 1.6, accuracy: 0.1))
        let estimate = try #require(estimator.estimate)
        // Weights: 1 / 0.1² = 100 for GPS, 1 / 0.5² = 4 for the pedometer.
        #expect(estimate.source == .gpsAndPedometer)
        #expect(isClose(estimate.speed, (1.6 * 100 + 1.2 * 4) / 104))
    }

    @Test func weakGPSDefersToThePedometer() throws {
        var estimator = SpeedEstimator(pedometerUncertainty: 0.5)
        estimator.addPedometer(speed: 1.4, at: date(0))
        estimator.addGPS(sample(at: 0.5, speed: 2.0, accuracy: 1.0))
        let estimate = try #require(estimator.estimate)
        // Weights: 1 for GPS, 4 for the pedometer.
        #expect(isClose(estimate.speed, (2.0 + 1.4 * 4) / 5))
    }

    @Test func pedometerGoesStaleWhenStepsStop() {
        var estimator = SpeedEstimator(pedometerMaxAge: 8)
        estimator.addPedometer(speed: 1.3, at: date(0))
        #expect(estimator.advance(to: date(8))?.speed == 1.3)
        #expect(estimator.advance(to: date(8.5)) == nil)
        #expect(estimator.pedometerSpeed == nil)
    }

    @Test func fallsBackToGPSWhenThePedometerStops() {
        var estimator = SpeedEstimator(pedometerMaxAge: 8)
        estimator.addPedometer(speed: 1.3, at: date(0))
        for second in 6...10 {
            estimator.addGPS(sample(at: Double(second), speed: 1.5, accuracy: 0.3))
        }
        #expect(estimator.estimate == SpeedEstimate(speed: 1.5, source: .gps))
    }

    @Test func fallsBackToThePedometerWhenGPSDrops() {
        var estimator = SpeedEstimator(gpsWindow: 4)
        estimator.addGPS(sample(at: 0, speed: 1.5, accuracy: 0.3))
        estimator.addPedometer(speed: 1.3, at: date(3))
        estimator.addPedometer(speed: 1.3, at: date(6))
        #expect(estimator.estimate == SpeedEstimate(speed: 1.3, source: .pedometer))
    }

    @Test func ignoresInaccurateGPS() {
        var estimator = SpeedEstimator(maxGPSAccuracy: 1.0)
        estimator.addPedometer(speed: 1.3, at: date(0))
        let estimate = estimator.addGPS(sample(at: 0.5, speed: 4.0, accuracy: 3.0))
        #expect(estimate == SpeedEstimate(speed: 1.3, source: .pedometer))
    }

    @Test func ignoresOutOfOrderPedometerReadings() {
        var estimator = SpeedEstimator()
        estimator.addPedometer(speed: 1.3, at: date(5))
        estimator.addPedometer(speed: 2.5, at: date(4))
        #expect(estimator.estimate?.speed == 1.3)
    }

    @Test func resetForgetsEverything() {
        var estimator = SpeedEstimator()
        estimator.addGPS(sample(at: 0, speed: 1.4, accuracy: 0.3))
        estimator.addPedometer(speed: 1.3, at: date(0))
        estimator.reset()
        #expect(estimator.estimate == nil)
        #expect(estimator.pedometerSpeed == nil)
        #expect(estimator.gpsAccuracy == nil)
    }
}
