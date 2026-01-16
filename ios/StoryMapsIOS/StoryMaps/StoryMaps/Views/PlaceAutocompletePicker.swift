/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import CoreLocation
import Combine

#if canImport(GooglePlaces)
import GooglePlaces
#endif

struct PlaceAutocompletePicker: View {
    let placeholder: String
    let iconName: String
    @Binding var place: Place?
    
    @State private var showingAutocomplete = false
    @State private var showingLocationPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Button(action: { showingAutocomplete = true }) {
                HStack {
                    Text(place?.name ?? placeholder)
                        .font(.body.weight(.medium))
                        .foregroundColor(place == nil ? .secondary : Color(red: 0.1, green: 0.1, blue: 0.1))
                    
                    Spacer()
                }
            }
            
            if placeholder == "Starting Point" {
                Button(action: { showingLocationPicker = true }) {
                    Image(systemName: "location.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
        )
        .background(
            Group {
                #if canImport(GooglePlaces)
                GooglePlacesAutocompleteView(place: $place, isPresented: $showingAutocomplete)
                    .frame(width: 0, height: 0)
                #else
                EmptyView()
                #endif
            }
        )
        .sheet(isPresented: $showingLocationPicker) {
            CurrentLocationPicker(place: $place)
        }
    }
}

#if canImport(GooglePlaces)
struct GooglePlacesAutocompleteView: UIViewControllerRepresentable {
    @Binding var place: Place?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Create a transparent container view controller
        let container = UIViewController()
        container.view.backgroundColor = .clear
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present the autocomplete controller when needed
        if isPresented && uiViewController.presentedViewController == nil {
            let autocompleteController = GMSAutocompleteViewController()
            autocompleteController.delegate = context.coordinator
            
            let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate, .placeID]
            autocompleteController.placeFields = fields
            
            uiViewController.present(autocompleteController, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSAutocompleteViewControllerDelegate {
        let parent: GooglePlacesAutocompleteView
        
        init(_ parent: GooglePlacesAutocompleteView) {
            self.parent = parent
        }
        
        func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
            print("✅ Place selected: \(place.name ?? "Unknown")")
            print("   Address: \(place.formattedAddress ?? "No address")")
            print("   Coordinate: \(place.coordinate.latitude), \(place.coordinate.longitude)")
            
            let selectedPlace = Place(
                id: place.placeID ?? UUID().uuidString,
                name: place.name ?? "Selected Location",
                address: place.formattedAddress ?? "Unknown Address",
                coordinate: Coordinate(clLocation: place.coordinate)
            )
            
            print("   Created Place: \(selectedPlace.name)")
            
            // Dismiss the autocomplete controller
            viewController.dismiss(animated: true) {
                // Update the binding on the main thread after dismissal
                DispatchQueue.main.async {
                    self.parent.place = selectedPlace
                    self.parent.isPresented = false
                    print("   ✅ Place binding updated")
                }
            }
        }
        
        func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
            print("❌ Autocomplete error: \(error.localizedDescription)")
            viewController.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
        
        func wasCancelled(_ viewController: GMSAutocompleteViewController) {
            print("ℹ️ Autocomplete cancelled by user")
            viewController.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
    }
}
#endif

struct CurrentLocationPicker: View {
    @Binding var place: Place?
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if locationManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Getting your location...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let error = locationManager.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Try Again") {
                        locationManager.requestLocation()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                } else if let currentPlace = locationManager.currentPlace {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text(currentPlace.address)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Use This Location") {
                        place = currentPlace
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Current Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentPlace: Place?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        locationManager.delegate = self
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
        guard let location = locations.first else { return }
        
        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let placemark = placemarks.first else {
                    self.errorMessage = "Could not find address for your location"
                    self.isLoading = false
                    return
                }
                
                let address = [
                    placemark.subThoroughfare,
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode
                ].compactMap { $0 }.joined(separator: ", ")
                
                self.currentPlace = Place(
                    id: UUID().uuidString,
                    name: placemark.name ?? "Current Location",
                    address: address.isEmpty ? "Current Location" : address,
                    coordinate: Coordinate(clLocation: location.coordinate)
                )
                
                self.isLoading = false
            } catch {
                self.errorMessage = "Could not find address for your location"
                self.isLoading = false
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
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
