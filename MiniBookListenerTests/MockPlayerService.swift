//
//  MockPlayerService.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 18.02.2025.
//

import AVFoundation
import Combine
@testable import MiniBookListener

class MockPlayerService: PlayerServiceProtocol {
    var audioPlayer: AVAudioPlayer? = nil
    var currentAudioIndex: Int = 0
    var audioFiles: [URL] = []
    var coverImageFile: URL?
    
    private var playbackTimePublisher = PassthroughSubject<TimeInterval, Never>()
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimePublisher.eraseToAnyPublisher()
    }

    var isPlaying = false
    var didLoadAudioFiles = false
    var playbackSpeed: Double = 1.0
    var seekTime: TimeInterval = 0.0

    func loadAudioFiles(from folderName: String) throws -> Bool {
        didLoadAudioFiles = true
        return true
    }
    
    func play() throws {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func next() throws -> Bool {
        currentAudioIndex += 1
        return true
    }
    
    func previous() throws -> Bool {
        currentAudioIndex = max(0, currentAudioIndex - 1)
        return true
    }
    
    func changePlaybackSpeed(to speed: Double) {
        playbackSpeed = speed
    }
    
    func startPlaybackTimeUpdates() {
        playbackTimePublisher.send(5.0)
    }
    
    func seek(to time: TimeInterval) {
        seekTime = time
    }
    
    func getCoverImage() -> Data? {
        return nil
    }
    
    func metadata(forIdentifier identifier: AVMetadataIdentifier) async -> String? {
        return "Mock Metadata"
    }
}
