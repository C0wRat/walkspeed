import Foundation

/// One speed reading, as reported by Core Location.
public struct SpeedSample: Equatable, Sendable {
    /// When the reading was taken.
    public var timestamp: Date
    /// The speed in metres per second. A negative value means the reading
    /// has no speed.
    public var speed: Double
    /// The uncertainty of ``speed`` in metres per second. A negative value
    /// means the uncertainty is unknown.
    public var speedAccuracy: Double

    public init(timestamp: Date, speed: Double, speedAccuracy: Double) {
        self.timestamp = timestamp
        self.speed = speed
        self.speedAccuracy = speedAccuracy
    }

    /// Whether the reading carries a usable speed.
    public var hasValidSpeed: Bool {
        speed >= 0 && speedAccuracy >= 0
    }
}

/// How far the latest speed reading can be trusted.
public enum SignalQuality: Comparable, Sendable {
    case unavailable
    case poor
    case fair
    case good

    /// Grades a reading by its speed accuracy in metres per second.
    public init(speedAccuracy: Double) {
        switch speedAccuracy {
        case ..<0: self = .unavailable
        case ...0.5: self = .good
        case ...1.0: self = .fair
        default: self = .poor
        }
    }
}
