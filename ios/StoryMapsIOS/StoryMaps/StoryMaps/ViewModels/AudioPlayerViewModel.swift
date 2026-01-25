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

    @Published var isPlaying = false
    @Published var currentSegmentIndex = 0
    @Published var isBuffering = false
    @Published var errorMessage: String?
    
    // Restoring missing properties
    private var audioPlayer: AVAudioPlayer?
    private var segments: [StorySegment] = []
    private var totalSegments: Int = 0
    
    var onSegmentChange: ((Int) -> Void)?
    
    private var remoteCommandTargets: [MPRemoteCommand: Any?] = [:]
    private var loadedSegmentIndex: Int?

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }
    
    deinit {
        // Since stop() and removeRemoteCommands() might touch MainActor properties,
        // we use a detached task to handle cleanup if needed, or rely on normal cleanup.
        // However, in Swift UI, @StateObject/ObservedObject usually outlive the view.
        // For deinit, we should be careful.
    }
    
    func loadStory(segments: [StorySegment], totalSegments: Int) {
        self.segments = segments
        self.totalSegments = totalSegments
        currentSegmentIndex = 0
        errorMessage = nil
        loadedSegmentIndex = nil
        audioPlayer = nil
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
        
        // Resume if already loaded for this segment
        if let player = audioPlayer, loadedSegmentIndex == currentSegmentIndex {
            player.play()
            isPlaying = true
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
            
            loadedSegmentIndex = currentSegmentIndex
            isPlaying = true
            isBuffering = false
            errorMessage = nil
            
            updateNowPlayingInfo(segment: segment)
        } catch {
            print("Audio playback error: \(error)")
            errorMessage = "Playback failed: \(error.localizedDescription)"
            isPlaying = false
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentSegmentIndex = 0
        loadedSegmentIndex = nil
        isBuffering = false
        updateNowPlayingInfo(segment: nil)
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
        
        remoteCommandTargets[commandCenter.playCommand] = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.play() }
            return .success
        }
        
        remoteCommandTargets[commandCenter.pauseCommand] = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }
        
        remoteCommandTargets[commandCenter.nextTrackCommand] = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.nextSegment() }
            return .success
        }
        
        remoteCommandTargets[commandCenter.previousTrackCommand] = commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.previousSegment() }
            return .success
        }
    }
    
    func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
        remoteCommandTargets.removeAll()
    }
    
    private func updateNowPlayingInfo(segment: StorySegment?) {
        guard let segment = segment else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
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
