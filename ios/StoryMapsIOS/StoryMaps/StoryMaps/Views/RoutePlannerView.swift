/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct RoutePlannerView: View {
    @ObservedObject var viewModel: RoutePlannerViewModel
    @Binding var appState: AppState
    var onRouteFound: (RouteDetails) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan Your Journey")
                    .font(.title2.weight(.bold))
                
                Text("Search locations and customize your experience.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Location Inputs
            VStack(spacing: 12) {
                PlaceAutocompletePicker(
                    placeholder: "Starting Point",
                    iconName: "mappin.circle.fill",
                    place: $viewModel.startPlace
                )
                
                PlaceAutocompletePicker(
                    placeholder: "Destination",
                    iconName: "location.fill",
                    place: $viewModel.endPlace
                )
            }
            
            // Travel Mode
            VStack(alignment: .leading, spacing: 12) {
                Text("TRAVEL MODE")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(RoutePlannerViewModel.TravelMode.allCases, id: \.self) { mode in
                        Button(action: { viewModel.travelMode = mode }) {
                            HStack(spacing: 8) {
                                Image(systemName: mode.iconName)
                                Text(mode.displayName)
                                    .font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(viewModel.travelMode == mode ? Color.white : Color.clear)
                            .foregroundColor(viewModel.travelMode == mode ? Color(red: 0.1, green: 0.1, blue: 0.1) : .secondary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            }
            
            // Story Style
            VStack(alignment: .leading, spacing: 12) {
                Text("STORY STYLE")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(StoryStyle.allCases) { style in
                        Button(action: { viewModel.selectedStyle = style }) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: style.iconName)
                                        .font(.title2)
                                    Spacer()
                                }
                                
                                Text(style.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(style.description)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(viewModel.selectedStyle == style ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.gray.opacity(0.05))
                            .foregroundColor(viewModel.selectedStyle == style ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
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
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Create Story Button
            Button(action: handleCreateStory) {
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
                .font(.headline)
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
        .background(Color.white.opacity(0.8))
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    private func handleCreateStory() {
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
