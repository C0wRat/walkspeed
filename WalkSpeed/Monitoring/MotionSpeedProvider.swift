import CoreMotion
import os

private let logger = Logger(subsystem: "com.c0wrat.walkspeed", category: "motion")

/// A reading from the pedometer in the motion coprocessor.
struct MotionReading: Sendable {
    /// The walking speed in metres per second, from the current pace.
    var speed: Double
    /// Steps per second, if the pedometer reported it.
    var cadence: Double?
    /// When the reading arrived.
    var timestamp: Date
}

/// Streams walking speed from the pedometer.
///
/// The pedometer counts steps with the motion coprocessor and estimates
/// stride length, so it measures speed indoors and anywhere else GPS can't.
/// It reports every few seconds while you walk, and stops when you stop.
@MainActor
final class MotionSpeedProvider {
    /// Called with every reading that has a pace.
    var onReading: (@MainActor (MotionReading) -> Void)?

    private let pedometer = CMPedometer()

    /// Whether this iPhone's pedometer can measure pace.
    var isAvailable: Bool {
        CMPedometer.isPaceAvailable()
    }

    /// Starts the pedometer. The first time, iOS asks for Motion & Fitness
    /// permission. Without it, readings never arrive and GPS works alone.
    func startUpdates() {
        guard isAvailable else { return }
        pedometer.startUpdates(from: .now) { @Sendable [weak self] data, error in
            if let error {
                logger.error("Pedometer update failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let data, let pace = data.currentPace?.doubleValue, pace > 0 else { return }
            let reading = MotionReading(speed: 1 / pace, cadence: data.currentCadence?.doubleValue, timestamp: .now)
            Task { @MainActor in
                self?.onReading?(reading)
            }
        }
    }

    func stopUpdates() {
        pedometer.stopUpdates()
    }
}
