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
    var userLocation: CLLocation?
    var currentPlace: Place?
    
    @State private var showingPlaceSearch = false
    @State private var showingLocationPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.googleSans(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .frame(width: 24)
            
            Button(action: { showingPlaceSearch = true }) {
                HStack {
                    Text(place?.name ?? placeholder)
                        .font(.googleSansSubheadline)
                        .fontWeight(.regular)
                        .foregroundColor(place == nil ? Color(red: 0.6, green: 0.6, blue: 0.6) : Color(red: 0.2, green: 0.2, blue: 0.2))
                    
                    Spacer()
                }
            }
            
            if placeholder == "Starting Point" {
                Button(action: { showingLocationPicker = true }) {
                    Image(systemName: "location.circle.fill")
                        .font(.googleSans(size: 16))
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
        )
        .fullScreenCover(isPresented: $showingPlaceSearch) {
            PlaceSearchView(
                placeholder: placeholder,
                userLocation: userLocation,
                currentPlace: currentPlace,
                selectedPlace: $place
            )
        }
        .sheet(isPresented: $showingLocationPicker) {
            CurrentLocationPicker(place: $place)
        }
    }
}

#if canImport(GooglePlaces)
struct GooglePlacesAutocompleteView: UIViewControllerRepresentable {
    @Binding var place: Place?
    @Binding var isPresented: Bool
    var userLocation: CLLocation?
    
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
            
            // Apply location bias if available
            if let location = userLocation {
                let filter = GMSAutocompleteFilter()
                
                // Set location bias (soft preference)
                filter.origin = location
                
                // Add country restriction based on user's location
                // This restricts results to the detected country
                let countryCode = getCountryCode(for: location.coordinate)
                if let country = countryCode {
                    filter.countries = [country]
                    print("🌍 Restricting results to country: \(country)")
                }
                
                autocompleteController.autocompleteFilter = filter
                print("📍 Applied location bias: \(location.coordinate)")
            }
            
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
    
    // Helper function to determine country code from coordinates
    func getCountryCode(for coordinate: CLLocationCoordinate2D) -> String? {
        // Simple geographic bounds-based country detection
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Australia
        if lat >= -44 && lat <= -10 && lon >= 113 && lon <= 154 {
            return "AU"
        }
        // United States (continental)
        else if lat >= 24 && lat <= 49 && lon >= -125 && lon <= -66 {
            return "US"
        }
        // United Kingdom
        else if lat >= 49.5 && lat <= 61 && lon >= -8 && lon <= 2 {
            return "GB"
        }
        // Canada
        else if lat >= 41 && lat <= 84 && lon >= -141 && lon <= -52 {
            return "CA"
        }
        // New Zealand
        else if lat >= -47 && lat <= -34 && lon >= 166 && lon <= 179 {
            return "NZ"
        }
        // Germany
        else if lat >= 47 && lat <= 55 && lon >= 5 && lon <= 15 {
            return "DE"
        }
        // France
        else if lat >= 41 && lat <= 51 && lon >= -5 && lon <= 10 {
            return "FR"
        }
        // Spain
        else if lat >= 36 && lat <= 44 && lon >= -10 && lon <= 5 {
            return "ES"
        }
        // Italy
        else if lat >= 36 && lat <= 47 && lon >= 6 && lon <= 19 {
            return "IT"
        }
        // Japan
        else if lat >= 24 && lat <= 46 && lon >= 123 && lon <= 146 {
            return "JP"
        }
        // India
        else if lat >= 6 && lat <= 36 && lon >= 68 && lon <= 97 {
            return "IN"
        }
        // Brazil
        else if lat >= -34 && lat <= 6 && lon >= -74 && lon <= -34 {
            return "BR"
        }
        
        // Default: no country restriction (will show global results)
        return nil
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
                        .font(.googleSansSubheadline)
                        .foregroundColor(.secondary)
                } else if let error = locationManager.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.googleSans(size: 48))
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.googleSansSubheadline)
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
                        .font(.googleSans(size: 48))
                        .foregroundColor(.green)
                    
                    Text(currentPlace.address)
                        .font(.googleSansSubheadline)
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
