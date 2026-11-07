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

/// A location fix, reduced to what WalkSpeed needs.
struct LocationReading: Sendable {
    var sample: SpeedSample
    /// Whether developer tools such as Xcode or devicectl simulated the fix.
    var isSimulated: Bool
    /// The uncertainty of the position in metres.
    var horizontalAccuracy: Double

    /// The speed accuracy assumed for simulated fixes, in metres per second.
    private static let simulatedSpeedAccuracy = 0.3

    init(_ location: CLLocation) {
        isSimulated = location.sourceInformation?.isSimulatedBySoftware ?? false
        horizontalAccuracy = location.horizontalAccuracy
        var speedAccuracy = location.speedAccuracy
        // Simulated fixes carry a speed but no speed accuracy. Trust them, so
        // the alerts can be tested on a phone without walking. Real fixes
        // without an accuracy are still rejected.
        if isSimulated, location.speed >= 0, speedAccuracy < 0 {
            speedAccuracy = Self.simulatedSpeedAccuracy
        }
        sample = SpeedSample(timestamp: location.timestamp, speed: location.speed, speedAccuracy: speedAccuracy)
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
    /// Called with every location fix.
    var onReading: (@MainActor (LocationReading) -> Void)?
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
        let readings = locations.map(LocationReading.init)
        MainActor.assumeIsolated {
            for reading in readings {
                onReading?(reading)
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
