/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CoreLocation
import Combine
import GoogleMaps

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentPlace: Place?
    @Published var userLocation: CLLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let geocoder = GMSGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        isLoading = true
        errorMessage = nil
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Location access denied. Please enable it in Settings."
        @unknown default:
            isLoading = false
            errorMessage = "Unknown location authorization status."
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.userLocation = location
            
            // Reverse geocode to get address for "Current Location" button usage
            geocoder.reverseGeocodeCoordinate(location.coordinate) { response, error in
                Task { @MainActor in
                    if let error = error {
                        self.errorMessage = "Could not find address for your location"
                        self.isLoading = false
                        return
                    }
                    
                    guard let address = response?.firstResult() else {
                        self.isLoading = false
                        return
                    }
                    
                    // Build address string from GMSAddress components
                    let addressString = address.lines?.joined(separator: ", ") ?? "Current Location"
                    
                    self.currentPlace = Place(
                        id: UUID().uuidString,
                        name: address.thoroughfare ?? "Current Location",
                        address: addressString,
                        coordinate: Coordinate(clLocation: location.coordinate)
                    )
                    
                    self.isLoading = false
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Ignore transient errors
            if (error as NSError).code == 0 { return }
            self.errorMessage = "Unable to retrieve your location. Please check permissions."
            self.isLoading = false
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
