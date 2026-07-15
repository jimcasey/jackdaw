import Foundation

/// A one-shot location fix — plain data, no CoreLocation type, so the capture layer
/// and tests never import CoreLocation.
struct LocationFix {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
}

enum LocationAuthStatus {
    case notDetermined
    case authorized      // when-in-use (or always)
    case denied          // denied / restricted
}

/// The location source, abstracted so tests inject a mock; only the concrete
/// `CoreLocationProvider` touches CoreLocation. `@MainActor` because the concrete
/// impl wraps `CLLocationManager` (main-actor-friendly) and the fix is written onto
/// a main-actor `ModelContext`.
@MainActor
protocol LocationProviding: AnyObject {
    /// Best-effort one-shot fix. Returns nil on denied / unavailable / timeout.
    /// Never throws; the caller does not await it inline in the capture path.
    func currentFix() async -> LocationFix?
    var authorizationStatus: LocationAuthStatus { get }
    func requestWhenInUseAuthorization()
    func prewarm()       // start warming a fix (Capture sheet appear)
    func stopPrewarm()   // stop updating to save battery (sheet dismiss)
}
