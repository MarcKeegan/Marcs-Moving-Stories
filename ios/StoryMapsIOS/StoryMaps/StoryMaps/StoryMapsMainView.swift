/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct StoryMapsMainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var routePlannerVM = RoutePlannerViewModel()
    @StateObject private var storyViewModel = StoryViewModel()
    @StateObject private var audioPlayer = AudioPlayerViewModel()
    @State private var appState: AppState = .planning
    @State private var showProfileSheet = false
    
    var body: some View {
        ZStack {
            Color(red: 34/255, green: 30/255, blue: 35/255)
                .ignoresSafeArea()
            
            // Planning/Loading content in ScrollView
            if appState.rawValue < AppState.readyToPlay.rawValue {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Image("Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 130, height: 40)
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.9))
                                
                                Spacer()
                                
                                Button(action: {
                                    AnalyticsService.shared.logEvent("profile_opened")
                                    showProfileSheet = true
                                }) {
                                    Image(systemName: "person.circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            .id("topOfScreen")
                            
                            // Hero Section
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Every journey has a story.")
                                        .font(.googleSans(size: 19))
                                        .fontWeight(.bold)
                                        .lineSpacing(2)
                                        .foregroundColor(.white)
                                   
                                }
                                
                                Text("Navigation apps tell you where to turn. StoryPath tells you what it feels like. Simply select your start and finish locations, pick a genre, and let us create a unique audio companion for the road ahead.")
                                    .font(.googleSans(size: 15))
                                    .fontWeight(.light)
                                    .lineSpacing(4)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                            .transition(.opacity)
                            
                            // Route Planner
                            RoutePlannerView(
                                viewModel: routePlannerVM,
                                appState: $appState,
                                onRouteFound: { route in
                                    handleGenerateStory(route: route)
                                }
                            )
                            .environmentObject(authViewModel)
                            .padding(.horizontal, 0)
                            .transition(.opacity)
                            
                            // Loading State
                            if appState == .generatingInitialSegment {
                                VStack(spacing: 24) {
                                    LottieView(name: "handtap")
                                        .frame(width: 120, height: 120)
                                    
                                    Text(storyViewModel.loadingMessage)
                                        .font(.googleSans(size: 19))
                                        .fontWeight(.medium)
                                        .lineSpacing(2)
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    // AdMob Banner
                                    BannerAd(unitID: "ca-app-pub-5422665078059042/7857666419")
                                        .frame(height: 60)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .transition(.opacity)
                                .id("loadingSection")
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
            
            // Full-screen Story Player (overlays everything when ready to play)
            if appState.rawValue >= AppState.readyToPlay.rawValue,
               let story = storyViewModel.story,
               let route = routePlannerVM.currentRoute {
                StoryPlayerView(
                    story: story,
                    route: route,
                    viewModel: storyViewModel,
                    audioPlayer: audioPlayer,
                    onReset: handleReset
                )
                .transition(.opacity)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.5), value: appState)
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authViewModel)
            }
        }
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "StoryMapsMainView")
        }
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
        audioPlayer.stop()
    }
}
