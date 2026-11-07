import Foundation
import Observation
import WalkSpeedCore

/// Connects the location readings to the alert logic and the beeps, and
/// publishes the live state for the UI.
@MainActor
@Observable
final class SpeedMonitor {
    /// Whether a monitoring session is running.
    private(set) var isMonitoring = false
    /// The smoothed walking speed in metres per second, or `nil` when it's
    /// unknown.
    private(set) var speed: Double? = nil
    /// How trustworthy the latest reading was.
    private(set) var signal: SignalQuality = .unavailable
    /// The location permission.
    private(set) var access: LocationAccess
    /// The running session, or the last one after monitoring stops.
    private(set) var session: WalkSession? = nil
    /// When the last session stopped, or `nil` while it's running.
    private(set) var sessionEndDate: Date? = nil

    let preferences: Preferences

    @ObservationIgnored private let location: LocationSpeedProvider
    @ObservationIgnored private let beeper = BeepPlayer()
    @ObservationIgnored private var smoother = SpeedSmoother()
    @ObservationIgnored private var detector: OverspeedDetector
    @ObservationIgnored private var staleReadingCheck: Task<Void, Never>? = nil
    /// Whether to start monitoring once the pending permission prompt is
    /// answered with precise location.
    @ObservationIgnored private var startsWhenAllowed = false
    @ObservationIgnored private var askedForPreciseLocation = false

    /// Readings older than this when they arrive are cached fixes, not the
    /// current speed.
    private static let maxReadingAge: TimeInterval = 5

    init(preferences: Preferences) {
        let location = LocationSpeedProvider()
        self.location = location
        self.preferences = preferences
        access = location.access
        detector = OverspeedDetector(configuration: preferences.alertConfiguration)

        location.onReading = { [weak self] reading in
            self?.handle(reading.sample)
        }
        location.onAccessChange = { [weak self] access in
            self?.accessDidChange(to: access)
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

    /// Stops monitoring. The session's totals stay available until the next
    /// start.
    func stop() {
        guard isMonitoring else { return }
        location.stopUpdates()
        staleReadingCheck?.cancel()
        staleReadingCheck = nil
        isMonitoring = false
        speed = nil
        signal = .unavailable
        sessionEndDate = .now
    }

    /// Plays an alert pattern with the current sound settings.
    func playTestBeep(_ level: AlertLevel) {
        beeper.play(level, volume: preferences.beepVolume, lowersOtherAudio: preferences.lowersMusic)
    }

    private func begin() {
        smoother.reset()
        detector = OverspeedDetector(configuration: preferences.alertConfiguration)
        session = WalkSession(startDate: .now)
        sessionEndDate = nil
        speed = nil
        signal = .unavailable
        isMonitoring = true
        location.startUpdates()
        staleReadingCheck = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                expireStaleReadings()
            }
        }
    }

    private func handle(_ sample: SpeedSample) {
        guard isMonitoring, -sample.timestamp.timeIntervalSinceNow < Self.maxReadingAge else { return }
        signal = SignalQuality(speedAccuracy: sample.speedAccuracy)
        update(speed: smoother.add(sample), at: sample.timestamp)
    }

    /// Clears the speed when readings stop arriving, for example indoors.
    private func expireStaleReadings() {
        guard isMonitoring, speed != nil else { return }
        let now = Date.now
        if smoother.advance(to: now) == nil {
            signal = .unavailable
            update(speed: nil, at: now)
        }
    }

    private func update(speed newSpeed: Double?, at date: Date) {
        speed = newSpeed
        let configuration = preferences.alertConfiguration
        detector.configuration = configuration
        session?.record(speed: newSpeed, zone: PaceZone(speed: newSpeed, configuration: configuration), at: date)
        guard let level = detector.update(speed: newSpeed, at: date) else { return }
        beeper.play(level, volume: preferences.beepVolume, lowersOtherAudio: preferences.lowersMusic)
        session?.recordAlert()
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
