import CoreMotion
import os

private let logger = Logger(subsystem: "com.c0wrat.walkspeed", category: "motion")

/// A reading from the pedometer in the motion coprocessor.
struct MotionReading: Sendable {
    /// The walking speed in metres per second from the current pace, if the
    /// pedometer reported one.
    var speed: Double?
    /// Steps per second, if the pedometer reported it.
    var cadence: Double?
    /// The steps counted since the pedometer started.
    var steps: Int
    /// The distance walked since the pedometer started in metres, if the
    /// pedometer reported it.
    var distance: Double?
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
    /// Called with every reading.
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
            guard let data else { return }
            let pace = data.currentPace?.doubleValue ?? 0
            let reading = MotionReading(
                speed: pace > 0 ? 1 / pace : nil,
                cadence: data.currentCadence?.doubleValue,
                steps: data.numberOfSteps.intValue,
                distance: data.distance?.doubleValue,
                timestamp: .now
            )
            Task { @MainActor in
                self?.onReading?(reading)
            }
        }
    }

    func stopUpdates() {
        pedometer.stopUpdates()
    }
}
