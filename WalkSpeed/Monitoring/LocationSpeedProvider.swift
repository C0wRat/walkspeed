import CoreLocation
import WalkSpeedCore

/// Whether WalkSpeed may measure speed, as far as location permission goes.
enum LocationAccess: Equatable, Sendable {
    /// The user hasn't been asked yet.
    case notDetermined
    /// The user turned location off for WalkSpeed.
    case denied
    /// Location is blocked on this device, for example by Screen Time.
    case restricted
    /// Location is allowed but Precise Location is off, so there's no speed.
    case approximateOnly
    /// Precise location is allowed.
    case granted

    init(status: CLAuthorizationStatus, accuracy: CLAccuracyAuthorization) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            self = accuracy == .fullAccuracy ? .granted : .approximateOnly
        @unknown default:
            self = .denied
        }
    }
}

/// Streams speed readings from Core Location, including while WalkSpeed is in
/// the background.
///
/// Updates have to start while the app is in the foreground. After that they
/// carry on in the background with only When In Use permission, and iOS shows
/// the blue location indicator.
@MainActor
final class LocationSpeedProvider: NSObject {
    /// Called with every reading.
    var onSample: (@MainActor (SpeedSample) -> Void)?
    /// Called when the location permission changes.
    var onAccessChange: (@MainActor (LocationAccess) -> Void)?

    private let manager = CLLocationManager()

    /// The key of the temporary precise location explanation in Info.plist.
    private static let precisionPurposeKey = "SpeedMeasurement"

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// The current location permission.
    var access: LocationAccess {
        LocationAccess(status: manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
    }

    /// Shows the system prompt for whatever permission is missing: location
    /// itself, or precise location for this session.
    func requestAccess() {
        switch access {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .approximateOnly:
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: Self.precisionPurposeKey)
        case .denied, .restricted, .granted:
            break
        }
    }

    func startUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }
}

// Core Location calls the delegate on the thread that created the manager,
// which is the main thread here.
extension LocationSpeedProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            SpeedSample(timestamp: $0.timestamp, speed: $0.speed, speedAccuracy: $0.speedAccuracy)
        }
        MainActor.assumeIsolated {
            for sample in samples {
                onSample?(sample)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let access = LocationAccess(status: manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
        MainActor.assumeIsolated {
            onAccessChange?(access)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // `locationUnknown` is temporary and Core Location keeps trying, while
        // a denial arrives through `locationManagerDidChangeAuthorization`.
        // Either way the speed goes stale and the UI reports the lost signal.
    }
}
