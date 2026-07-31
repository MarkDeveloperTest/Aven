import CoreLocation

@MainActor
final class LocationAuthorizationClient: NSObject {
    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    static func requestAlwaysPreciseIfNeeded() async {
        let client = LocationAuthorizationClient()
        await client.requestAlwaysPreciseIfNeeded()
    }

    private func requestAlwaysPreciseIfNeeded() async {
        locationManager.delegate = self

        switch locationManager.authorizationStatus {
        case .notDetermined:
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied, .restricted:
            return
        @unknown default:
            return
        }

        guard locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse
        else {
            return
        }

        if locationManager.authorizationStatus == .authorizedWhenInUse {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                locationManager.requestAlwaysAuthorization()
            }
        }

        guard locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse
        else {
            return
        }

        if locationManager.accuracyAuthorization == .reducedAccuracy {
            do {
                try await locationManager.requestTemporaryFullAccuracyAuthorization(
                    withPurposeKey: "AvenPreciseLocation"
                )
            } catch {
                AppLogger.privacy.error("Precise location authorization request failed")
            }
        }
    }
}

extension LocationAuthorizationClient: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume()
        authorizationContinuation = nil
    }
}
