/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
class AudioPlayerViewModel: NSObject, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    @Published var isPlaying = false
    @Published var currentSegmentIndex = 0
    @Published var isBuffering = false
    
    private var audioPlayer: AVAudioPlayer?
    private var segments: [StorySegment] = []
    private var totalSegments: Int = 0
    
    var onSegmentChange: ((Int) -> Void)?
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }
    
    func loadStory(segments: [StorySegment], totalSegments: Int) {
        self.segments = segments
        self.totalSegments = totalSegments
        currentSegmentIndex = 0
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard currentSegmentIndex < segments.count else {
            isBuffering = true
            return
        }
        
        let segment = segments[currentSegmentIndex]
        
        guard let audioData = segment.audioData else {
            isBuffering = true
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            isBuffering = false
            
            updateNowPlayingInfo(segment: segment)
        } catch {
            print("Audio playback error: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func nextSegment() {
        guard currentSegmentIndex + 1 < segments.count else {
            isBuffering = true
            isPlaying = false
            return
        }
        
        currentSegmentIndex += 1
        onSegmentChange?(currentSegmentIndex)
        
        if isPlaying {
            play()
        }
    }
    
    func previousSegment() {
        guard currentSegmentIndex > 0 else { return }
        
        currentSegmentIndex -= 1
        onSegmentChange?(currentSegmentIndex)
        
        if isPlaying {
            play()
        }
    }
    
    func updateSegments(_ segments: [StorySegment]) {
        self.segments = segments
        
        // Resume if we were buffering and the segment is now available
        if isBuffering && currentSegmentIndex < segments.count && segments[currentSegmentIndex].audioData != nil {
            isBuffering = false
            if isPlaying {
                play()
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextSegment()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousSegment()
            return .success
        }
    }
    
    private func updateNowPlayingInfo(segment: StorySegment) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "StoryMaps - Segment \(segment.id)"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        
        if let duration = audioPlayer?.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

extension AudioPlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.nextSegment()
        }
    }
}
