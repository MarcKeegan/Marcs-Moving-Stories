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
    private var notificationObservers: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
        setupNotificationObservers()
    }

    deinit {
        // Notification tokens and remote-command targets may be removed from
        // any thread, so this cleanup is safe outside the main actor.
        for token in notificationObservers {
            NotificationCenter.default.removeObserver(token)
        }
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
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
            refreshNowPlayingPlaybackState()
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
            Log.audio.error("Audio playback error: \(error.localizedDescription)")
            errorMessage = "Playback failed: \(error.localizedDescription)"
            isPlaying = false
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        refreshNowPlayingPlaybackState()
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), player.duration)
        refreshNowPlayingPlaybackState()
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
            Log.audio.error("Failed to setup audio session: \(error.localizedDescription)")
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

        remoteCommandTargets[commandCenter.changePlaybackPositionCommand] = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self.seek(to: position) }
            return .success
        }
    }

    // MARK: - Audio session interruptions & route changes

    private func setupNotificationObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionsKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            Task { @MainActor [weak self] in
                self?.handleInterruption(type: type, options: options)
            }
        }
        notificationObservers.append(interruption)

        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reason: reason)
            }
        }
        notificationObservers.append(routeChange)
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            // Phone call, Siri, another app's audio: remember state so we can resume.
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying { pause() }
        case .ended:
            if wasPlayingBeforeInterruption && options.contains(.shouldResume) {
                play()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason) {
        // Headphones unplugged / Bluetooth dropped: pause rather than blast the speaker.
        if reason == .oldDeviceUnavailable && isPlaying {
            pause()
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
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer?.currentTime ?? 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let duration = audioPlayer?.duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Keeps the lock-screen elapsed time and play/pause state accurate
    /// without rebuilding the whole Now Playing dictionary.
    private func refreshNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer?.currentTime ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension AudioPlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.nextSegment()
        }
    }
}
