import Foundation
import Observation
import WalkSpeedCore

/// The latest raw reading from each sensor, for the sensor readout in
/// Settings.
struct SensorReadings {
    var location: LocationReading?
    var motion: MotionReading?
}

/// Connects the GPS and pedometer readings to the alert logic and the beeps,
/// and publishes the live state for the UI.
@MainActor
@Observable
final class SpeedMonitor {
    /// Whether a monitoring session is running.
    private(set) var isMonitoring = false
    /// The estimated walking speed in metres per second, or `nil` when it's
    /// unknown.
    private(set) var speed: Double? = nil
    /// The sensors the speed comes from, or `nil` when it's unknown.
    private(set) var source: SpeedSource? = nil
    /// How good the GPS signal is.
    private(set) var signal: SignalQuality = .unavailable
    /// Whether the pedometer is reporting steps.
    private(set) var isPedometerActive = false
    /// The latest raw sensor readings.
    private(set) var readings = SensorReadings()
    /// The location permission.
    private(set) var access: LocationAccess
    /// The running session, or the last one after monitoring stops.
    private(set) var session: WalkSession? = nil
    /// When the last session stopped, or `nil` while it's running.
    private(set) var sessionEndDate: Date? = nil
    /// The walk saved when monitoring last stopped.
    private(set) var lastSavedWalk: Walk? = nil

    let preferences: Preferences

    @ObservationIgnored private let location: LocationSpeedProvider
    @ObservationIgnored private let motion = MotionSpeedProvider()
    @ObservationIgnored private let beeper = BeepPlayer()
    @ObservationIgnored private let history: WalkHistory?
    @ObservationIgnored private var estimator = SpeedEstimator()
    @ObservationIgnored private var route = RouteRecorder()
    @ObservationIgnored private var trace: SpeedTrace? = nil
    @ObservationIgnored private var detector: OverspeedDetector
    @ObservationIgnored private var ticker: Task<Void, Never>? = nil
    /// Whether to start monitoring once the pending permission prompt is
    /// answered with precise location.
    @ObservationIgnored private var startsWhenAllowed = false
    @ObservationIgnored private var askedForPreciseLocation = false

    /// Location fixes older than this when they arrive are cached, not the
    /// current speed.
    private static let maxReadingAge: TimeInterval = 5

    init(preferences: Preferences, history: WalkHistory? = nil) {
        let location = LocationSpeedProvider()
        self.location = location
        self.preferences = preferences
        self.history = history
        access = location.access
        detector = OverspeedDetector(configuration: preferences.alertConfiguration)

        location.onReading = { [weak self] reading in
            self?.handle(reading)
        }
        location.onAccessChange = { [weak self] access in
            self?.accessDidChange(to: access)
        }
        motion.onReading = { [weak self] reading in
            self?.handle(reading)
        }
    }

    /// Where the current speed sits relative to the limit.
    var zone: PaceZone {
        PaceZone(speed: speed, configuration: preferences.alertConfiguration)
    }

    /// Starts monitoring, asking for location permission first if needed.
    func start() {
        guard !isMonitoring else { return }
        switch access {
        case .granted:
            begin()
        case .notDetermined, .approximateOnly:
            startsWhenAllowed = true
            askedForPreciseLocation = access == .approximateOnly
            location.requestAccess()
        case .denied, .restricted:
            break
        }
    }

    /// Stops monitoring and saves the walk. The session's totals stay
    /// available until the next start.
    func stop() {
        guard isMonitoring else { return }
        location.stopUpdates()
        motion.stopUpdates()
        ticker?.cancel()
        ticker = nil
        isMonitoring = false
        clearLiveState()
        let endDate = Date.now
        sessionEndDate = endDate
        saveWalk(endingAt: endDate)
    }

    /// Plays an alert pattern with the current sound settings.
    func playTestBeep(_ level: AlertLevel) {
        beeper.play(level, volume: preferences.beepVolume, lowersOtherAudio: preferences.lowersMusic)
    }

    private func begin() {
        estimator.reset()
        detector = OverspeedDetector(configuration: preferences.alertConfiguration)
        let startDate = Date.now
        session = WalkSession(startDate: startDate)
        sessionEndDate = nil
        route = RouteRecorder()
        trace = SpeedTrace(startDate: startDate)
        readings = SensorReadings()
        clearLiveState()
        isMonitoring = true
        location.startUpdates()
        motion.startUpdates()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                tick()
            }
        }
    }

    private func clearLiveState() {
        speed = nil
        source = nil
        signal = .unavailable
        isPedometerActive = false
    }

    private func handle(_ reading: LocationReading) {
        guard isMonitoring, -reading.sample.timestamp.timeIntervalSinceNow < Self.maxReadingAge else { return }
        readings.location = reading
        apply(estimator.addGPS(reading.sample))
        let point = RoutePoint(
            latitude: reading.latitude,
            longitude: reading.longitude,
            timestamp: reading.sample.timestamp,
            isOverLimit: zone == .overLimit
        )
        route.add(point, horizontalAccuracy: reading.horizontalAccuracy)
    }

    private func handle(_ reading: MotionReading) {
        guard isMonitoring else { return }
        readings.motion = reading
        if let speed = reading.speed {
            apply(estimator.addPedometer(speed: speed, at: reading.timestamp))
        }
    }

    /// Runs every second, so stale readings expire and alerts repeat on time
    /// even when the sensors go quiet.
    private func tick() {
        guard isMonitoring else { return }
        apply(estimator.advance(to: .now))
    }

    private func apply(_ estimate: SpeedEstimate?) {
        let now = Date.now
        speed = estimate?.speed
        source = estimate?.source
        signal = SignalQuality(speedAccuracy: estimator.gpsAccuracy ?? -1)
        isPedometerActive = estimator.pedometerSpeed != nil

        let configuration = preferences.alertConfiguration
        detector.configuration = configuration
        session?.record(speed: speed, zone: PaceZone(speed: speed, configuration: configuration), at: now)
        trace?.add(speed: speed, at: now)
        guard let level = detector.update(speed: speed, at: now) else { return }
        beeper.play(level, volume: preferences.beepVolume, lowersOtherAudio: preferences.lowersMusic)
        session?.recordAlert()
    }

    private func saveWalk(endingAt endDate: Date) {
        guard let session, var trace else { return }
        trace.finish()
        self.trace = nil
        let summary = WalkSummary(
            session: session,
            endDate: endDate,
            limit: preferences.limit,
            routeDistance: route.distance,
            pedometerDistance: readings.motion?.distance,
            steps: readings.motion?.steps
        )
        lastSavedWalk = history?.save(summary, route: route.points, speedTrace: trace.points)
    }

    private func accessDidChange(to newAccess: LocationAccess) {
        access = newAccess
        switch newAccess {
        case .granted:
            if startsWhenAllowed {
                startsWhenAllowed = false
                begin()
            }
        case .approximateOnly:
            stop()
            // Location was just allowed, but without Precise Location. Ask
            // once for precise location for this session.
            if startsWhenAllowed, !askedForPreciseLocation {
                askedForPreciseLocation = true
                location.requestAccess()
            } else {
                startsWhenAllowed = false
            }
        case .denied, .restricted:
            startsWhenAllowed = false
            stop()
        case .notDetermined:
            break
        }
    }
}
