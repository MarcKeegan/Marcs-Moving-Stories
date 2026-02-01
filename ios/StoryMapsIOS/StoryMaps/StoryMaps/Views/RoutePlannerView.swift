/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import CoreLocation

struct RoutePlannerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: RoutePlannerViewModel
    @Binding var appState: AppState
    var onRouteFound: (RouteDetails) -> Void
    
    @StateObject private var locationManager = LocationManager() // For location biasing
    @State private var showSignInPrompt = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan Your Journey")
                    .font(.googleSans(size: 19))
                    .fontWeight(.bold)
                    .lineSpacing(2)
                    .foregroundColor(.white)
                
                Text("Search locations and customize your experience.")
                    .font(.googleSans(size: 13))
                    .fontWeight(.regular)
                    .lineSpacing(2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                locationManager.requestLocation()
            }
            
            // Location Inputs
            VStack(spacing: 12) {
                PlaceAutocompletePicker(
                    placeholder: "Starting Point",
                    iconName: "mappin.circle.fill",
                    place: $viewModel.startPlace,
                    userLocation: locationManager.userLocation,
                    currentPlace: locationManager.currentPlace
                )
                
                PlaceAutocompletePicker(
                    placeholder: "Destination",
                    iconName: "location.fill",
                    place: $viewModel.endPlace,
                    userLocation: viewModel.startPlace != nil ? 
                        CLLocation(latitude: viewModel.startPlace!.coordinate.latitude, longitude: viewModel.startPlace!.coordinate.longitude) : 
                        locationManager.userLocation,
                    currentPlace: locationManager.currentPlace
                )
            }
            
            // Travel Mode
            VStack(alignment: .leading, spacing: 12) {
                Text("TRAVEL MODE")
                    .font(.googleSansCaption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 8) {
                    ForEach(RoutePlannerViewModel.TravelMode.allCases, id: \.self) { mode in
                        Button(action: {
                            viewModel.travelMode = mode
                            AnalyticsService.shared.logEvent("travel_mode_changed", parameters: ["mode": mode.displayName])
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.iconName)
                                Text(mode.displayName)
                                    .font(.googleSansSubheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(height: 20)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(viewModel.travelMode == mode ? Color(red: 0.23, green: 0.16, blue: 0.25) : Color.clear)
                            .foregroundColor(viewModel.travelMode == mode ? Color.white : .white.opacity(0.7))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(3)
                .background(Color(red: 0.13, green: 0.12, blue: 0.14))
                .cornerRadius(10)
            }
            
            // Story Style
            VStack(alignment: .leading, spacing: 12) {
                Text("STORY STYLE")
                    .font(.googleSansCaption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StoryStyle.allCases) { style in
                        Button(action: {
                            viewModel.selectedStyle = style
                            AnalyticsService.shared.logEvent("story_style_selected", parameters: ["style": style.displayName])
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: style.iconName)
                                    .font(.googleSansTitle2)
                                
                                Text(style.displayName)
                                    .font(.googleSansSubheadline)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.leading)
                                
                                Text(style.description)
                                    .font(.googleSansCaption)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150)
                            .background(viewModel.selectedStyle == style ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(viewModel.selectedStyle == style ? Color.clear : Color.gray.opacity(0.2), lineWidth: 2)
                            )
                        }
                    }
                }
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.googleSansCaption)
                    .foregroundColor(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Create Story Button
            Button(action: {
                if authViewModel.isGuest {
                    showSignInPrompt = true
                } else {
                    handleCreateStory()
                }
            }) {
                HStack(spacing: 8) {
                    if viewModel.isCalculating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Planning Journey...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Create your story")
                    }
                }
                .font(.googleSansHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                .foregroundColor(.white)
                .cornerRadius(30)
            }
            .disabled(viewModel.startPlace == nil || viewModel.endPlace == nil || viewModel.isCalculating)
            .opacity((viewModel.startPlace == nil || viewModel.endPlace == nil || viewModel.isCalculating) ? 0.5 : 1.0)
        }
        .padding(24)
        .background(Color(red: 0.23, green: 0.16, blue: 0.25))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .alert("Sign In Required", isPresented: $showSignInPrompt) {
            Button("Sign In") {
                AnalyticsService.shared.logEvent("guest_sign_in_prompted")
                authViewModel.signOut() // Exit guest mode and return to auth
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Create an account or sign in to generate personalized audio stories for your journey.")
        }
    }
    
    private func handleCreateStory() {
        AnalyticsService.shared.logEvent("create_story_tapped", parameters: [
            "style": viewModel.selectedStyle.displayName,
            "travel_mode": viewModel.travelMode.displayName
        ])
        Task {
            do {
                let route = try await viewModel.calculateRoute()
                onRouteFound(route)
            } catch {
                print("Route calculation error: \(error)")
            }
        }
    }
}
