/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import CoreLocation
import GooglePlaces
import Combine

@MainActor
class PlaceSearchService: NSObject, ObservableObject {
    @Published var suggestions: [Place] = []
    @Published var autocompleteResults: [Place] = []
    @Published var isSearching = false
    @Published var isFetchingSuggestions = false
    @Published var errorMessage: String?
    
    private let placesClient = GMSPlacesClient.shared()
    private let token = GMSAutocompleteSessionToken.init()
    
    func fetchSuggestions(near coordinate: CLLocationCoordinate2D) async {
        isFetchingSuggestions = true
        errorMessage = nil
        
        // Let's create a few "suggested" searches locally to get interesting nearby places
        // Google Places SDK doesn't have a direct "give me interesting things nearby" for free/simple
        // so we'll fetch likelihoods (nearby contexts) first
        
        do {
            let likelihoods = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[GMSPlaceLikelihood], Error>) in
                placesClient.findPlaceLikelihoodsFromCurrentLocation(withPlaceFields: [.name, .formattedAddress, .coordinate, .placeID, .types]) { (likelihoods, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: likelihoods ?? [])
                }
            }
            
            self.suggestions = likelihoods.map { likelihood in
                Place(
                    id: likelihood.place.placeID ?? UUID().uuidString,
                    name: likelihood.place.name ?? "Nearby Point of Interest",
                    address: likelihood.place.formattedAddress ?? "Nearby",
                    coordinate: Coordinate(clLocation: likelihood.place.coordinate)
                )
            }.filter { $0.name != "Nearby Point of Interest" }
            
            // If we didn't get enough likelihoods, let's add some hardcoded "interesting" targets that are always good
            // In a more advanced version, we'd use a search query nearby
            
        } catch {
            print("❌ Error fetching place likelihoods: \(error.localizedDescription)")
            // Fallback: If current location fails, we might just leave suggestions empty or show defaults
            self.suggestions = []
        }
        
        isFetchingSuggestions = false
    }
    
    func searchAutocomplete(query: String, bias: CLLocationCoordinate2D?) {
        guard !query.isEmpty else {
            self.autocompleteResults = []
            return
        }
        
        isSearching = true
        
        let filter = GMSAutocompleteFilter()
        filter.type = .address
        
        if let bias = bias {
            filter.origin = CLLocation(latitude: bias.latitude, longitude: bias.longitude)
        }
        
        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: token) { [weak self] (results, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Autocomplete error: \(error.localizedDescription)")
                self.isSearching = false
                return
            }
            
            guard let results = results else {
                self.autocompleteResults = []
                self.isSearching = false
                return
            }
            
            // For each prediction, we need to fetch the place details to get coordinates
            // This is a bit heavy, so we might want to just show names first and fetch details on tap
            // But for a better UI, we'll try to map them to Place objects (with dummy coords for now, 
            // and fetch real ones when selected)
            
            self.autocompleteResults = results.map { prediction in
                Place(
                    id: prediction.placeID,
                    name: prediction.attributedPrimaryText.string,
                    address: prediction.attributedSecondaryText?.string ?? "",
                    coordinate: Coordinate(latitude: 0, longitude: 0) // Dummy, real coord fetched on selection
                )
            }
            
            self.isSearching = false
        }
    }
    
    func fetchPlaceDetails(placeID: String) async throws -> Place {
        return try await withCheckedThrowingContinuation { continuation in
            let fields: GMSPlaceField = [.name, .formattedAddress, .coordinate, .placeID]
            placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: token) { (place, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let place = place else {
                    continuation.resume(throwing: NSError(domain: "PlaceSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Place not found"]))
                    return
                }
                
                let detailedPlace = Place(
                    id: place.placeID ?? placeID,
                    name: place.name ?? "Selected Location",
                    address: place.formattedAddress ?? "Unknown Address",
                    coordinate: Coordinate(clLocation: place.coordinate)
                )
                
                continuation.resume(returning: detailedPlace)
            }
        }
    }
}
