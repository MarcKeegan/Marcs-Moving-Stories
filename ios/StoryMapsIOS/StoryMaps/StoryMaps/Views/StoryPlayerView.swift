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
    @State private var autoScroll = true
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 24) {
                // Hero Map
                GoogleMapView(
                    route: route,
                    currentSegmentIndex: audioPlayer.currentSegmentIndex,
                    totalSegments: story.totalSegmentsEstimate
                )
                .frame(height: 300)
                .cornerRadius(32)
                .overlay(
                    // Destination Overlay
                    VStack {
                        Spacer()
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: route.travelMode == "DRIVING" ? "car.fill" : "figure.walk")
                                    .font(.googleSansTitle3)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DESTINATION")
                                        .font(.googleSansCaption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                    
                                    Text(route.endAddress)
                                        .font(.googleSans(size: 14))
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                }
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            
                            Spacer()
                        }
                        .padding(16)
                    }
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                // Sticky Player Controls
                VStack(spacing: 0) {
                    HStack {
                        // Status Indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(audioPlayer.isPlaying ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            if audioPlayer.isBuffering {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Buffering...")
                                        .font(.googleSansCaption)
                                }
                                .foregroundColor(.orange)
                            } else {
                                Text(audioPlayer.isPlaying ? "Playing" : "Paused")
                                    .font(.googleSansCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(route.duration) Journey")
                            .font(.googleSans(size: 14))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Auto-scroll Toggle
                        Button(action: { autoScroll.toggle() }) {
                            Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.googleSansTitle3)
                                .foregroundColor(autoScroll ? .white : .white.opacity(0.5))
                        }
                        
                        // Play/Pause Button
                        Button(action: { audioPlayer.togglePlayback() }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.googleSans(size: 44))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.23, green: 0.16, blue: 0.25))
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    if let error = audioPlayer.errorMessage {
                        Text(error)
                            .foregroundColor(.white)
                            .font(.googleSansCaption)
                            .padding(.top, 8)
                            .padding(.horizontal)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                    
                    // Buffering error with retry button
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
                        .padding(.top, 8)
                    }
                }
                
                // Story Text Stream
                ScrollView {
                    VStack(spacing: 40) {
                        ForEach(story.segments) { segment in
                            VStack(spacing: 20) {
                                Text(segment.text)
                                    .font(.googleSans(size: 16))
                                    .lineSpacing(8)
                                    .foregroundColor(.white)
                                    .opacity(segment.id <= audioPlayer.currentSegmentIndex + 1 ? 1.0 : 0.3)
                                    .id(segment.id)
                                
                                if segment.id < story.segments.count {
                                    Divider()
                                        .frame(width: 100)
                                        .background(Color.gray.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        
                        // Loading indicator for next segment
                        if viewModel.isBackgroundGenerating {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading next paragraph...")
                                    .font(.googleSansCaption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .textCase(.uppercase)
                            }
                            .padding(.vertical, 20)
                            .opacity(0.7)
                        }
                    }
                    .padding(.vertical, 20)
                    .onChange(of: audioPlayer.currentSegmentIndex) { _, newIndex in
                        if autoScroll && newIndex < story.segments.count {
                            withAnimation {
                                proxy.scrollTo(story.segments[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            .onAppear {
                audioPlayer.loadStory(segments: story.segments, totalSegments: story.totalSegmentsEstimate)
                audioPlayer.onSegmentChange = { index in
                    checkBuffering(currentIndex: index)
                }
                checkBuffering(currentIndex: audioPlayer.currentSegmentIndex)
            }
            .onChange(of: story.segments.count) { _, _ in
                audioPlayer.updateSegments(story.segments)
            }
        }
    }
    
    private func checkBuffering(currentIndex: Int) {
        // Buffer ahead when we're getting close to the end of buffered content
        let neededBufferIndex = currentIndex + 2
        
        if story.segments.count < neededBufferIndex && story.segments.count < story.totalSegmentsEstimate {
            viewModel.bufferNextSegments()
        }
    }
}

