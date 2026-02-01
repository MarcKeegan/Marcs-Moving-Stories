/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI

struct StoryPlayerView: View {
    let story: AudioStory
    let route: RouteDetails
    @ObservedObject var viewModel: StoryViewModel
    @ObservedObject var audioPlayer: AudioPlayerViewModel
    var onReset: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showProfileSheet = false
    @State private var autoScroll = true
    @State private var centerOnLocation = false
    
    // Bottom sheet states
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    
    // Sheet height constants
    private let collapsedHeight: CGFloat = 280
    private let expandedHeight: CGFloat = UIScreen.main.bounds.height * 0.75
    
    private var currentSheetHeight: CGFloat {
        let baseHeight = isExpanded ? expandedHeight : collapsedHeight
        let height = baseHeight - dragOffset
        return min(max(height, collapsedHeight), expandedHeight)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Full-screen Map
                GoogleMapView(
                    route: route,
                    currentSegmentIndex: audioPlayer.currentSegmentIndex,
                    totalSegments: story.totalSegmentsEstimate,
                    centerOnLocationTrigger: $centerOnLocation
                )
                .ignoresSafeArea()
                
                // Header Overlay (Logo + Profile)
                VStack {
                    HStack {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 130, height: 40)
                        
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
                    .padding(.bottom, 12)
                    
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top + 8 : 52)
                
                // Location Button Overlay (above bottom sheet)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            centerOnLocation = true
                            AnalyticsService.shared.logEvent("center_on_location_tapped")
                        }) {
                            Image(systemName: "location.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color(red: 0.15, green: 0.12, blue: 0.18).opacity(0.9))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, currentSheetHeight + 16)
                }
                
                // Bottom Sheet
                VStack(spacing: 0) {
                    // Grab Handle
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                    
                    // Destination Info Row
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESTINATION")
                                .font(.googleSansCaption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            
                            Text(route.endAddress)
                                .font(.googleSans(size: 16))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            // Route stats
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Image(systemName: route.travelMode == "DRIVING" ? "car.fill" : "figure.walk")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                    Text(route.duration)
                                        .font(.googleSansCaption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(16)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                    Text(route.distance)
                                        .font(.googleSansCaption)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(16)
                            }
                        }
                        
                        Spacer()
                        
                        // Play Button
                        Button(action: {
                            let eventName = audioPlayer.isPlaying ? "playback_pause_tapped" : "playback_play_tapped"
                            AnalyticsService.shared.logEvent(eventName, parameters: ["segment_index": audioPlayer.currentSegmentIndex])
                            audioPlayer.togglePlayback()
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    
                    // Scrollable Story Text
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(story.segments) { segment in
                                    Text(segment.text)
                                        .font(.googleSans(size: 16))
                                        .lineSpacing(8)
                                        .foregroundColor(.white)
                                        .opacity(segment.id <= audioPlayer.currentSegmentIndex + 1 ? 1.0 : 0.3)
                                        .id(segment.id)
                                }
                                
                                // Loading indicator
                                if viewModel.isBackgroundGenerating {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .tint(.white)
                                        Text("Loading next paragraph...")
                                            .font(.googleSansCaption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .textCase(.uppercase)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .opacity(0.7)
                                }
                                
                                // End Journey Button
                                Button(action: {
                                    AnalyticsService.shared.logEvent("end_journey_tapped", parameters: [
                                        "segments_completed": audioPlayer.currentSegmentIndex
                                    ])
                                    onReset()
                                }) {
                                    HStack(spacing: 12) {
                                        Text("End Journey & Start New")
                                            .font(.googleSansHeadline)
                                        
                                        Image(systemName: "arrow.right")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .cornerRadius(30)
                                }
                                .padding(.top, 20)
                                
                                Spacer().frame(height: 60)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                        .onChange(of: audioPlayer.currentSegmentIndex) { _, newIndex in
                            if autoScroll && newIndex < story.segments.count {
                                withAnimation {
                                    proxy.scrollTo(story.segments[newIndex].id, anchor: .top)
                                }
                            }
                        }
                    }
                    
                    // Error Messages
                    if let error = audioPlayer.errorMessage {
                        Text(error)
                            .foregroundColor(.white)
                            .font(.googleSansCaption)
                            .padding(12)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                    }
                    
                    if let bufferingError = viewModel.bufferingError {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text(bufferingError)
                                .font(.googleSansCaption)
                                .foregroundColor(.white)
                            
                            Button("Retry") {
                                viewModel.retryFailedSegments()
                            }
                            .font(.googleSansCaption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color(red: 0.2, green: 0.15, blue: 0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    
                    if audioPlayer.isBuffering {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.orange)
                            Text("Buffering...")
                                .font(.googleSansCaption)
                                .foregroundColor(.orange)
                        }
                        .padding(.bottom, 8)
                    }
                }
                .frame(height: currentSheetHeight)
                .frame(maxWidth: .infinity)
                .background(
                    Color(red: 0.23, green: 0.16, blue: 0.20)
                        .cornerRadius(24, corners: [.topLeft, .topRight])
                )
                .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8, blendDuration: 0), value: currentSheetHeight)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            let dragAmount = value.translation.height
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            
                            // Snap threshold: 60px drag or fast flick (200pt/s)
                            let snapThreshold: CGFloat = 60
                            let velocityThreshold: CGFloat = 200
                            
                            // Reset drag offset first
                            dragOffset = 0
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                if isExpanded {
                                    // Currently expanded - check if should collapse
                                    if dragAmount > snapThreshold || velocity > velocityThreshold {
                                        isExpanded = false
                                        AnalyticsService.shared.logEvent("player_sheet_collapsed")
                                    }
                                } else {
                                    // Currently collapsed - check if should expand
                                    if dragAmount < -snapThreshold || velocity < -velocityThreshold {
                                        isExpanded = true
                                        AnalyticsService.shared.logEvent("player_sheet_expanded")
                                    }
                                }
                            }
                        }
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            audioPlayer.loadStory(segments: story.segments, totalSegments: story.totalSegmentsEstimate)
            audioPlayer.onSegmentChange = { index in
                if audioPlayer.isPlaying {
                    checkBuffering(currentIndex: index)
                }
            }
        }
        .onChange(of: story.segments.count) { _, _ in
            audioPlayer.updateSegments(story.segments)
        }
        .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
            if isPlaying {
                checkBuffering(currentIndex: audioPlayer.currentSegmentIndex)
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authViewModel)
            }
        }
    }
    
    private func checkBuffering(currentIndex: Int) {
        let neededBufferIndex = currentIndex + 2
        if story.segments.count < neededBufferIndex && story.segments.count < story.totalSegmentsEstimate {
            viewModel.bufferNextSegments()
        }
    }
}

// Helper extension for rounded corners on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
