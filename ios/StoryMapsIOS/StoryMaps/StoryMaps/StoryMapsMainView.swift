/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct StoryMapsMainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var routePlannerVM = RoutePlannerViewModel()
    @StateObject private var storyViewModel = StoryViewModel()
    @State private var appState: AppState = .planning
    
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.94)
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Image(systemName: "map.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9))
                            
                            Spacer()
                            
                            Button("Sign out") {
                                authViewModel.signOut()
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        .id("topOfScreen") // Anchor for scrolling to top
                        
                        // Hero Section (visible until ready to play)
                        if appState.rawValue < AppState.readyToPlay.rawValue {
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Journey. Your Soundtrack.")
                                        .font(.system(size: 32, weight: .bold, design: .serif))
                                        .lineSpacing(2)
                                    
                                    Text("Your Story.")
                                        .font(.system(size: 32, weight: .bold, design: .serif))
                                        .italic()
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Navigation apps tell you where to turn. StoryMaps tells you what it feels like. Simply drop a pin for your start and finish, pick a genre, and let us create a unique audio companion for the road ahead.")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .transition(.opacity)
                        }
                        
                        // Route Planner (visible during planning/generating)
                        if appState.rawValue <= AppState.generatingInitialSegment.rawValue {
                            RoutePlannerView(
                                viewModel: routePlannerVM,
                                appState: $appState,
                                onRouteFound: { route in
                                    handleGenerateStory(route: route)
                                }
                            )
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        }
                        
                        // Loading State
                        if appState == .generatingInitialSegment {
                            VStack(spacing: 24) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                
                                Text(storyViewModel.loadingMessage)
                                    .font(.title3)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                // AdMob Banner
                                BannerAd(unitID: "ca-app-pub-5422665078059042/7857666419")
                                    .frame(height: 60) // Slightly taller to ensure visibility
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .transition(.opacity)
                            .id("loadingSection")
                        }
                        
                        // Story Player (visible when ready to play)
                        if appState.rawValue >= AppState.readyToPlay.rawValue,
                           let story = storyViewModel.story,
                           let route = routePlannerVM.currentRoute {
                            StoryPlayerView(
                                story: story,
                                route: route,
                                viewModel: storyViewModel
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .transition(.opacity)
                            
                            // Reset Button
                            Button(action: handleReset) {
                                HStack(spacing: 12) {
                                    Text("End Journey & Start New")
                                        .font(.headline)
                                    
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .cornerRadius(30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                )
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 60)
                        }
                    }
                }
                .onChange(of: appState) { oldState, newState in
                    if newState == .generatingInitialSegment {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                proxy.scrollTo("loadingSection", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.light) // Force light mode for consistent UI design
        .animation(.easeInOut(duration: 0.5), value: appState)
    }
    
    private func handleGenerateStory(route: RouteDetails) {
        Task {
            appState = .generatingInitialSegment
            do {
                try await storyViewModel.generateInitialStory(for: route)
                appState = .readyToPlay
            } catch {
                print("Story generation error: \(error)")
                appState = .planning
                routePlannerVM.errorMessage = "Failed to generate story. Please try again."
            }
        }
    }
    
    private func handleReset() {
        appState = .planning
        routePlannerVM.reset()
        storyViewModel.reset()
    }
}
