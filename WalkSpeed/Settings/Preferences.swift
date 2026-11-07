import Foundation
import Observation
import WalkSpeedCore

/// The user's settings, saved in `UserDefaults`.
@MainActor
@Observable
final class Preferences {
    /// The speed limit in metres per second.
    var limit: Double {
        didSet { defaults.set(limit, forKey: Key.limit) }
    }

    /// The unit speeds are shown in.
    var unit: SpeedUnit {
        didSet { defaults.set(unit.rawValue, forKey: Key.unit) }
    }

    /// How long you have to be over the limit before the first beep, in seconds.
    var alertDelay: TimeInterval {
        didSet { defaults.set(alertDelay, forKey: Key.alertDelay) }
    }

    /// How often to beep again while you stay over the limit, in seconds.
    var repeatInterval: TimeInterval {
        didSet { defaults.set(repeatInterval, forKey: Key.repeatInterval) }
    }

    /// The beep volume from 0 to 1, relative to the media volume.
    var beepVolume: Double {
        didSet { defaults.set(beepVolume, forKey: Key.beepVolume) }
    }

    /// Whether to lower other audio while a beep plays.
    var lowersMusic: Bool {
        didSet { defaults.set(lowersMusic, forKey: Key.lowersMusic) }
    }

    /// The default limit: 1.5 m/s, about 5.4 km/h or 3.4 mph.
    static let defaultLimit = 1.5
    static let alertDelayOptions: [TimeInterval] = [0, 2, 5, 10]
    static let repeatIntervalOptions: [TimeInterval] = [3, 5, 10, 20]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        limit = defaults.object(forKey: Key.limit) as? Double ?? Self.defaultLimit
        unit = defaults.string(forKey: Key.unit).flatMap(SpeedUnit.init(rawValue:)) ?? .preferred()
        alertDelay = defaults.object(forKey: Key.alertDelay) as? TimeInterval ?? 2
        repeatInterval = defaults.object(forKey: Key.repeatInterval) as? TimeInterval ?? 5
        beepVolume = defaults.object(forKey: Key.beepVolume) as? Double ?? 1
        lowersMusic = defaults.object(forKey: Key.lowersMusic) as? Bool ?? true
    }

    /// The alert settings, in the form the detector takes them.
    var alertConfiguration: AlertConfiguration {
        AlertConfiguration(limit: limit, alertDelay: alertDelay, repeatInterval: repeatInterval)
    }

    private enum Key {
        static let limit = "limit"
        static let unit = "unit"
        static let alertDelay = "alertDelay"
        static let repeatInterval = "repeatInterval"
        static let beepVolume = "beepVolume"
        static let lowersMusic = "lowersMusic"
    }
}
