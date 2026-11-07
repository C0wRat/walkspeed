import Foundation

/// How insistent an alert is, based on how far over the limit you are.
///
/// The raw value is the number of beeps.
public enum AlertLevel: Int, CaseIterable, Comparable, Sendable {
    /// Just over the limit: one beep.
    case gentle = 1
    /// Clearly over the limit: two beeps.
    case firm = 2
    /// Well over the limit: three beeps.
    case urgent = 3

    /// How many beeps the alert plays.
    public var beepCount: Int { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The settings that decide when ``OverspeedDetector`` beeps.
///
/// Speeds are in metres per second and durations in seconds.
public struct AlertConfiguration: Equatable, Sendable {
    /// The speed limit.
    public var limit: Double
    /// How long you have to stay over the limit before the first beep.
    public var alertDelay: TimeInterval
    /// How often to beep again while you stay over the limit.
    public var repeatInterval: TimeInterval
    /// How far below the limit you have to drop to end an over-limit
    /// episode. This stops the alert flapping when you hover at the limit.
    public var hysteresis: Double
    /// Speeds above this are assumed to come from a vehicle, so the detector
    /// stays quiet.
    public var vehicleSpeed: Double
    /// How far over the limit firm alerts start.
    public var firmExcess: Double
    /// How far over the limit urgent alerts start.
    public var urgentExcess: Double

    /// Speeds at or above this fraction of the limit count as near the limit.
    public static let nearLimitFraction = 0.9

    public init(
        limit: Double,
        alertDelay: TimeInterval = 2,
        repeatInterval: TimeInterval = 5,
        hysteresis: Double = 0.1,
        vehicleSpeed: Double = 4.5,
        firmExcess: Double = 0.15,
        urgentExcess: Double = 0.4
    ) {
        self.limit = limit
        self.alertDelay = alertDelay
        self.repeatInterval = repeatInterval
        self.hysteresis = hysteresis
        self.vehicleSpeed = vehicleSpeed
        self.firmExcess = firmExcess
        self.urgentExcess = urgentExcess
    }

    /// The alert level for a speed over the limit.
    public func level(for speed: Double) -> AlertLevel {
        switch speed - limit {
        case urgentExcess...: .urgent
        case firmExcess...: .firm
        default: .gentle
        }
    }
}

/// Decides when to beep, given a stream of smoothed speeds.
///
/// Pass every smoothed speed to ``update(speed:at:)``. It returns an
/// ``AlertLevel`` when it's time to beep:
///
/// 1. When the speed first goes over the limit, the detector waits for
///    ``AlertConfiguration/alertDelay``, in case the reading is a blip.
/// 2. Then it beeps, and keeps beeping every
///    ``AlertConfiguration/repeatInterval`` while you stay over.
/// 3. The episode ends once the speed drops more than
///    ``AlertConfiguration/hysteresis`` below the limit. Hovering just under
///    the limit doesn't beep, but it doesn't end the episode either, so going
///    back over beeps straight away.
///
/// Unknown speeds and vehicle speeds end the episode and never beep.
public struct OverspeedDetector: Sendable {
    public var configuration: AlertConfiguration

    private enum Phase: Equatable {
        case underLimit
        case pending(since: Date)
        case overLimit(lastAlert: Date)
    }

    private var phase: Phase = .underLimit

    /// Location updates arrive about once a second, with some jitter. A small
    /// tolerance keeps a 5-second repeat from slipping to 6 seconds.
    private static let timingTolerance: TimeInterval = 0.25

    public init(configuration: AlertConfiguration) {
        self.configuration = configuration
    }

    /// Whether an over-limit episode has started beeping and hasn't ended yet.
    public var isAlerting: Bool {
        if case .overLimit = phase { return true }
        return false
    }

    /// Processes a smoothed speed and returns the alert to play, if any.
    ///
    /// - Parameters:
    ///   - speed: The smoothed speed in metres per second, or `nil` if it's
    ///     unknown.
    ///   - date: When the speed was measured.
    public mutating func update(speed: Double?, at date: Date) -> AlertLevel? {
        guard let speed, speed <= configuration.vehicleSpeed else {
            phase = .underLimit
            return nil
        }

        guard speed > configuration.limit else {
            if speed <= configuration.limit - configuration.hysteresis {
                phase = .underLimit
            } else if case .pending = phase {
                phase = .underLimit
            }
            return nil
        }

        switch phase {
        case .underLimit:
            phase = .pending(since: date)
            return alertIfDelayElapsed(since: date, now: date, speed: speed)
        case let .pending(since):
            return alertIfDelayElapsed(since: since, now: date, speed: speed)
        case let .overLimit(lastAlert):
            guard date.timeIntervalSince(lastAlert) >= configuration.repeatInterval - Self.timingTolerance else {
                return nil
            }
            phase = .overLimit(lastAlert: date)
            return configuration.level(for: speed)
        }
    }

    /// Ends any over-limit episode.
    public mutating func reset() {
        phase = .underLimit
    }

    private mutating func alertIfDelayElapsed(since start: Date, now: Date, speed: Double) -> AlertLevel? {
        guard now.timeIntervalSince(start) >= configuration.alertDelay - Self.timingTolerance else {
            return nil
        }
        phase = .overLimit(lastAlert: now)
        return configuration.level(for: speed)
    }
}

/// Where a speed sits relative to the limit. The app uses it to choose its
/// colours and status text.
public enum PaceZone: Sendable {
    /// No trustworthy speed yet.
    case unknown
    /// Comfortably under the limit.
    case comfortable
    /// Under the limit, but close to it.
    case nearLimit
    /// Over the limit.
    case overLimit
    /// Too fast to be walking, probably in a vehicle.
    case vehicle

    public init(speed: Double?, configuration: AlertConfiguration) {
        guard let speed else {
            self = .unknown
            return
        }
        if speed > configuration.vehicleSpeed {
            self = .vehicle
        } else if speed > configuration.limit {
            self = .overLimit
        } else if speed >= configuration.limit * AlertConfiguration.nearLimitFraction {
            self = .nearLimit
        } else {
            self = .comfortable
        }
    }
}
