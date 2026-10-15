//
//  VideoPlaybackAudioSessionManager.swift
//  PiliPod
//
//  Created by Codex on 2026/6/9.
//

#if canImport(UIKit)
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
final class VideoPlaybackAudioSessionManager: ObservableObject {
    struct PlaybackInfo: Equatable {
        var title: String
        var artist: String
        var artworkURL: URL?
        var duration: TimeInterval
        var elapsedTime: TimeInterval
        var playbackRate: Double
        var isPlaying: Bool
        var isLiveStream = false
        var supportsSeeking = true
    }

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let audioSession = PlaybackAudioSessionWorker()
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var artworkLoadTask: Task<Void, Never>?
    private var currentArtworkURL: URL?
    private var currentArtworkImage: UIImage?
    private var lastPlaybackInfo: PlaybackInfo?
    private var didRegisterCommands = false
    private var isActive = false
    private var notificationObservers: [NSObjectProtocol] = []

    private var onPlay: (() -> Void)?
    private var onPause: (() -> Void)?
    private var onSeek: ((TimeInterval) -> Void)?

    func configureHandlers(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.onPlay = onPlay
        self.onPause = onPause
        self.onSeek = onSeek
    }

    func activate() {
        isActive = true
        audioSession.activate()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        installAudioSessionObserversIfNeeded()
        registerRemoteCommandsIfNeeded()
    }

    func deactivate() {
        isActive = false
        teardown()
        audioSession.deactivate()
    }

    func updateNowPlaying(info: PlaybackInfo) {
        guard isActive else { return }
        let normalizedInfo = PlaybackInfo(
            title: info.title,
            artist: info.artist,
            artworkURL: info.artworkURL,
            duration: info.duration,
            elapsedTime: info.elapsedTime,
            playbackRate: info.isPlaying ? info.playbackRate : 0,
            isPlaying: info.isPlaying,
            isLiveStream: info.isLiveStream,
            supportsSeeking: info.supportsSeeking
        )

        lastPlaybackInfo = normalizedInfo

        if currentArtworkURL != normalizedInfo.artworkURL {
            currentArtworkURL = normalizedInfo.artworkURL
            currentArtworkImage = nil
            loadArtworkIfNeeded(from: normalizedInfo.artworkURL)
        }

        audioSession.setPlaying(normalizedInfo.isPlaying)

        commandCenter.changePlaybackPositionCommand.isEnabled = normalizedInfo.supportsSeeking && !normalizedInfo.isLiveStream
        publishNowPlaying(info: normalizedInfo, artwork: currentArtworkImage)
    }

    private func teardown() {
        artworkLoadTask?.cancel()
        artworkLoadTask = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
        unregisterRemoteCommands()
        removeAudioSessionObservers()
        lastPlaybackInfo = nil
        currentArtworkURL = nil
        currentArtworkImage = nil
    }

    private func registerRemoteCommandsIfNeeded() {
        guard !didRegisterCommands else { return }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        commandTargets = [
            (
                commandCenter.playCommand,
                commandCenter.playCommand.addTarget { [weak self] _ in
                    self?.handlePlay()
                    return .success
                }
            ),
            (
                commandCenter.pauseCommand,
                commandCenter.pauseCommand.addTarget { [weak self] _ in
                    self?.handlePause()
                    return .success
                }
            ),
            (
                commandCenter.togglePlayPauseCommand,
                commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                    self?.handleToggle()
                    return .success
                }
            ),
            (
                commandCenter.changePlaybackPositionCommand,
                commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                    guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                        return .commandFailed
                    }
                    self?.handleSeek(to: event.positionTime)
                    return .success
                }
            )
        ]

        didRegisterCommands = true
    }

    private func unregisterRemoteCommands() {
        guard didRegisterCommands else { return }

        for (command, target) in commandTargets {
            command.removeTarget(target)
        }

        commandTargets.removeAll()
        didRegisterCommands = false
    }

    private func handlePlay() {
        print("[AudioSession] Remote command: play")
        onPlay?()
    }

    private func handlePause() {
        print("[AudioSession] Remote command: pause")
        onPause?()
    }

    private func handleToggle() {
        let isPlaying = lastPlaybackInfo?.isPlaying ?? false
        
        if lastPlaybackInfo?.isPlaying ?? false {
            onPause?()
        } else {
            onPlay?()
        }
    }

    private func handleSeek(to position: TimeInterval) {
        onSeek?(position)
    }

    private func publishNowPlaying(info: PlaybackInfo, artwork: UIImage?) {
        let effectiveRate = info.isPlaying ? Float(max(info.playbackRate, 0)) : 0

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPNowPlayingInfoPropertyPlaybackRate: effectiveRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Float(max(info.playbackRate, 0)),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if info.isLiveStream {
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        } else {
            let effectiveDuration = max(info.duration, 0)
            let effectiveElapsed = min(
                max(info.elapsedTime, 0),
                effectiveDuration > 0 ? effectiveDuration : info.elapsedTime
            )
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = effectiveDuration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = effectiveElapsed
        }

        if let artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func installAudioSessionObserversIfNeeded() {
        guard notificationObservers.isEmpty else { return }

        let center = NotificationCenter.default
        notificationObservers = [
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            },
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleMediaServicesReset()
            }
        ]
    }

    private func removeAudioSessionObservers() {
        let center = NotificationCenter.default
        for observer in notificationObservers {
            center.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            print("[AudioSession] Received interruption with unknown payload")
            return
        }

        print("[AudioSession][Interruption] type=\(type.rawValue) lastPlaying=\(lastPlaybackInfo?.isPlaying.description ?? "nil")")

        if type == .began {
            audioSession.interruptionBegan()
            return
        }

        guard type == .ended, let playbackInfo = lastPlaybackInfo, playbackInfo.isPlaying else { return }

        audioSession.interruptionEnded()
        publishNowPlaying(info: playbackInfo, artwork: currentArtworkImage)
    }

    private func handleMediaServicesReset() {

        guard let playbackInfo = lastPlaybackInfo else { return }
        audioSession.mediaServicesReset(isPlaying: playbackInfo.isPlaying)
        registerRemoteCommandsIfNeeded()
        publishNowPlaying(info: playbackInfo, artwork: currentArtworkImage)
    }

    private func loadArtworkIfNeeded(from url: URL?) {
        artworkLoadTask?.cancel()
        artworkLoadTask = nil

        guard let url else { return }

        artworkLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let image = await SharedRemoteImageStore.shared.image(for: url)
            guard !Task.isCancelled, self.currentArtworkURL == url else { return }

            self.currentArtworkImage = image
            print("[AudioSession] Artwork \(image == nil ? "load failed" : "loaded") for \(url.absoluteString)")

            if let playbackInfo = self.lastPlaybackInfo {
                self.publishNowPlaying(info: playbackInfo, artwork: image)
            }
        }
    }
}

/// AVAudioSession activation and engine start/stop can wait for the audio service.
/// Keep all audio resources on one queue, including their creation and release.
/// The queue is shared because AVAudioSession is process-wide.
private final class PlaybackAudioSessionWorker: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "com.pilipod.playback-audio-session", qos: .userInitiated)
    // Accessed only on queue. A departing page must not deactivate its successor.
    private static weak var owner: PlaybackAudioSessionWorker?
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    private var isSessionActive = false
    private var wantsPlayback = false
    private var isInterrupted = false

    func activate() {
        Self.queue.async {
            if let previous = Self.owner, previous !== self {
                previous.wantsPlayback = false
                previous.isSessionActive = false
                previous.releaseEngine()
            }
            Self.owner = self
            self.wantsPlayback = true
            self.isInterrupted = false
            self.ensureReady()
        }
    }

    func setPlaying(_ playing: Bool) {
        Self.queue.async {
            guard Self.owner === self else { return }
            self.wantsPlayback = playing
            if playing {
                self.ensureReady()
            } else if self.engine?.isRunning == true {
                self.engine?.stop()
            }
        }
    }

    func deactivate() {
        Self.queue.async {
            self.wantsPlayback = false
            self.releaseEngine()
            self.isSessionActive = false
            guard Self.owner === self else { return }
            Self.owner = nil
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                self.record(error, context: "停用音频会话")
            }
        }
    }

    func interruptionBegan() {
        Self.queue.async {
            guard Self.owner === self else { return }
            self.isInterrupted = true
            self.isSessionActive = false
            self.engine?.stop()
        }
    }

    func interruptionEnded() {
        Self.queue.async {
            guard Self.owner === self else { return }
            self.isInterrupted = false
            self.wantsPlayback = true
            self.ensureReady()
        }
    }

    func mediaServicesReset(isPlaying: Bool) {
        Self.queue.async {
            guard Self.owner === self else { return }
            self.releaseEngine()
            self.isSessionActive = false
            self.isInterrupted = false
            self.wantsPlayback = isPlaying
            if isPlaying { self.ensureReady() }
        }
    }

    private func ensureReady() {
        guard wantsPlayback, !isInterrupted else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            if !isSessionActive {
                try session.setCategory(.playback, mode: .moviePlayback)
                try session.setActive(true)
                isSessionActive = true
            }
            let engine = self.engine ?? makeEngine()
            if !engine.isRunning { try engine.start() }
        } catch {
            record(error, context: "准备播放音频会话")
        }
    }

    private func makeEngine() -> AVAudioEngine {
        let engine = AVAudioEngine()
        let sourceNode = AVAudioSourceNode { _, _, _, audioBufferList -> OSStatus in
            for buffer in UnsafeMutableAudioBufferListPointer(audioBufferList) {
                if let pointer = buffer.mData {
                    memset(pointer, 0, Int(buffer.mDataByteSize))
                }
            }
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(
            sourceNode,
            to: engine.mainMixerNode,
            format: AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        )
        self.engine = engine
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Self.queue.async { [weak self] in
                guard let self, Self.owner === self else { return }
                self.ensureReady()
            }
        }
        return engine
    }

    private func releaseEngine() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine?.stop()
        engine = nil
    }

    private func record(_ error: Error, context: String) {
        DispatchQueue.main.async {
            ErrorLogService.record(error, context: context)
        }
    }

    deinit {
        // A retained PiP page can outlive its SwiftUI destination. Even when
        // explicit deactivation is skipped, release engine resources off main.
        let engine = engine
        let observer = configurationObserver
        Self.queue.async {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            engine?.stop()
        }
    }
}
#endif
