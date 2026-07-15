import Foundation
import CoreLocation

/// The concrete location source. Wraps `CLLocationManager`, pre-warms on Capture
/// appear, and caches the freshest fix so rapid multi-capture doesn't cold-spin GPS
/// three times. The `LocationProviding` protocol hides this choice, so we can swap
/// to `CLLocationUpdate.liveUpdates` later without touching `CaptureService`.
@MainActor
final class CoreLocationProvider: NSObject, LocationProviding {
    static let shared = CoreLocationProvider()

    private let manager = CLLocationManager()
    private var latestFix: LocationFix?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var authorizationStatus: LocationAuthStatus {
        switch manager.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        default: return .denied
        }
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func prewarm() {
        guard authorizationStatus == .authorized else { return }
        manager.startUpdatingLocation()
    }

    func stopPrewarm() {
        manager.stopUpdatingLocation()
    }

    /// Return the freshest cached fix, or poll briefly (~3s) for the first one.
    func currentFix() async -> LocationFix? {
        guard authorizationStatus == .authorized else { return nil }
        manager.startUpdatingLocation()
        if let latestFix { return latestFix }
        for _ in 0..<30 {
            try? await Task.sleep(for: .milliseconds(100))
            if let latestFix { return latestFix }
        }
        return latestFix
    }
}

extension CoreLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let fix = LocationFix(latitude: loc.coordinate.latitude,
                              longitude: loc.coordinate.longitude,
                              horizontalAccuracy: loc.horizontalAccuracy)
        Task { @MainActor in self.latestFix = fix }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Leave the last cached fix in place; a note simply stays timestamp-only.
    }
}
