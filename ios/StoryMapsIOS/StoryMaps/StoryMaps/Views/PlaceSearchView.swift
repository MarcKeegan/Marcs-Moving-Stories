/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import CoreLocation

struct PlaceSearchView: View {
    let placeholder: String
    let userLocation: CLLocation?
    let currentPlace: Place?
    @Binding var selectedPlace: Place?
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var searchService = PlaceSearchService()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("", text: $searchText, prompt: 
                        Text(placeholder)
                            .foregroundColor(.white.opacity(0.4))
                    )
                    .font(.googleSansSubheadline)
                    .foregroundColor(.white)
                    .onChange(of: searchText) { _, newValue in
                        searchService.searchAutocomplete(query: newValue, bias: userLocation?.coordinate)
                    }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                List {
                    if searchText.isEmpty {
                        // Current Location row
                        if let current = currentPlace {
                            Section {
                                PlaceRow(place: current, icon: "location.fill") {
                                    selectPlace(current)
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        
                        // Suggestions Section
                        Section {
                            if searchService.isFetchingSuggestions {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(.white)
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            } else if searchService.suggestions.isEmpty {
                                Text("No suggestions found nearby.")
                                    .font(.googleSansCaption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(searchService.suggestions) { place in
                                    PlaceRow(place: place, icon: "sparkles") {
                                        selectPlace(place)
                                    }
                                }
                            }
                        } header: {
                            Text(placeholder == "Starting Point" ? "SUGGESTED STARTING POINTS" : "SUGGESTED DESTINATIONS")
                                .font(.googleSansCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        // Autocomplete Results
                        Section {
                            if searchService.isSearching {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(.white)
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(searchService.autocompleteResults) { result in
                                    PlaceRow(place: result, icon: "mappin.and.ellipse") {
                                        Task {
                                            do {
                                                let fullPlace = try await searchService.fetchPlaceDetails(placeID: result.id)
                                                selectPlace(fullPlace)
                                            } catch {
                                                print("Error fetching details: \(error)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }
            .background(Color(red: 25/255, green: 22/255, blue: 26/255))
            .navigationTitle("Find a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.googleSansSubheadline)
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                if let bias = userLocation?.coordinate {
                    Task {
                        await searchService.fetchSuggestions(near: bias)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func selectPlace(_ place: Place) {
        selectedPlace = place
        dismiss()
    }
}

struct PlaceRow: View {
    let place: Place
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue) // Keeping blue for brand accent
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.googleSansSubheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(place.address)
                        .font(.googleSansCaption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

#Preview {
    PlaceSearchView(
        placeholder: "Search for a destination",
        userLocation: CLLocation(latitude: -37.8136, longitude: 144.9631),
        currentPlace: nil,
        selectedPlace: .constant(nil)
    )
}
