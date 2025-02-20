//
//  PlayerService.swift
//  MiniBookPlayer
//
//  Created by Tim Hazhyi on 26.11.2023.
//

import Foundation
import ComposableArchitecture
import Combine
import AVFoundation

enum PlayerServiceError: String, LocalizedError {
    case lastFileInBook
    case fileNotExist
    
    var errorDescription: String? { self.rawValue }
}

@DependencyClient
struct PlayerClient {
    var loadFiles: @Sendable ([URL]) throws -> Void
    var setTimePublisher: @Sendable (PassthroughSubject<TimeInterval, Never>) throws -> Void
    var loadCurrentAudioFile: @Sendable () throws -> (TimeInterval, Int)
    var play: @Sendable () throws -> Bool
    var pause: @Sendable () -> Void
    var next: @Sendable () throws -> (TimeInterval, Int)
    var previous: @Sendable () throws -> (TimeInterval, Int)
    var changePlaybackSpeed: @Sendable (Float) throws -> Void
    var seek: @Sendable (TimeInterval) throws -> Void
    var metadata: @Sendable () async throws -> String?
    var startPlaybackTimeUpdates: @Sendable () -> Void
    
    
}

extension PlayerClient: DependencyKey {
    static let liveValue: Self = {
        let service = PlayerService()
        
        return Self(
            loadFiles: { service.loadFiles(files: $0) },
            setTimePublisher: { service.setTimePublisher($0) },
            loadCurrentAudioFile: { try service.loadCurrentAudioFile() },
            play: { service.play() },
            pause: { service.pause() },
            next: { try service.next() },
            previous: { try service.previous() },
            changePlaybackSpeed: { service.changePlaybackSpeed(to: $0)},
            seek: { service.seek(to: $0) },
            metadata: { try await service.extractCommonMetadata() },
            startPlaybackTimeUpdates: { service.startPlaybackTimeUpdates() }
        )
    }()
}

extension DependencyValues {
    var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}

private final class PlayerService: NSObject, AVAudioPlayerDelegate {
    struct Constant {
        static let defaultRate: Float = 1.0
    }
    
    private var playbackTimePublisher = PassthroughSubject<TimeInterval, Never>()
    private var audioPlayer = AVAudioPlayer()
    private var files: [URL] = []
    private var currentAudioIndex: Int = 0
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        playbackTimePublisher.send(player.duration)
    }
    
    func loadFiles(files: [URL]) {
        self.files = files
    }
    
    func setTimePublisher(_ publisher: PassthroughSubject<TimeInterval, Never>) {
        self.playbackTimePublisher = publisher
    }
    
    func loadCurrentAudioFile() throws -> (TimeInterval, Int) {
        let file = files[currentAudioIndex]
        let rate = audioPlayer.rate == 0 ? Constant.defaultRate : audioPlayer.rate
        audioPlayer = try AVAudioPlayer(contentsOf: file)
        audioPlayer.enableRate = true
        audioPlayer.delegate = self
        audioPlayer.rate = rate
        audioPlayer.prepareToPlay()
        return (audioPlayer.duration, currentAudioIndex)
    }
    
    func play() -> Bool {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func next() throws -> (TimeInterval, Int) {
        guard currentAudioIndex + 1 < files.count else { throw PlayerServiceError.lastFileInBook }
        currentAudioIndex += 1
        return try loadCurrentAudioFile()
    }
    
    func previous() throws -> (TimeInterval, Int) {
        guard currentAudioIndex > 0 else { throw PlayerServiceError.fileNotExist }
        currentAudioIndex -= 1
        return try loadCurrentAudioFile()
    }
    
    func changePlaybackSpeed(to speed: Float) {
        audioPlayer.rate = speed
    }
    
    func startPlaybackTimeUpdates()  {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.playbackTimePublisher.send(audioPlayer.currentTime)
        }
    }
    
    func seek(to time: TimeInterval) {
        guard audioPlayer.duration > time else { return }
        audioPlayer.currentTime = time
    }
    
    private func metadata(forIdentifier identifier: AVMetadataIdentifier) async throws -> String? {
        guard currentAudioIndex < files.count else { return nil }
        let asset = AVAsset(url: files[currentAudioIndex])
        let commonMetadata = try await asset.load(.commonMetadata)
        let metadataItems = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: identifier)
        if let metadataItem = metadataItems.first {
            let stringValue = try await metadataItem.load(.stringValue)
            return stringValue
        }
        return nil
    }
    
    func extractCommonMetadata() async throws -> String? {
        return try await metadata(forIdentifier: .commonIdentifierTitle)
    }
}
