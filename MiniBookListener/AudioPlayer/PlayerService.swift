//
//  PlayerService.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 26.11.2023.
//

import Foundation
import AVFoundation
import Combine

protocol PlayerServiceProtocol {
    var audioPlayer: AVAudioPlayer? { get }
    var currentAudioIndex: Int { get }
    var currentBook: Book? { get }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    
    func setCurrentBook(_ value: Book)
    func loadCurrentAudioFile() throws -> Bool
    func play() throws
    func pause()
    func next() throws -> Bool
    func previous() throws -> Bool
    func changePlaybackSpeed(to speed: Double)
    func startPlaybackTimeUpdates()
    func seek(to time: TimeInterval)
    func getCoverImage() -> Data?
    func metadata(forIdentifier identifier: AVMetadataIdentifier) async -> String?
}

final class PlayerService: NSObject, PlayerServiceProtocol {
    struct Constant {
        static let defaultRate: Float = 1.0
    }
    
    private(set) var audioPlayer: AVAudioPlayer?
    private(set) var currentAudioIndex: Int = 0
    private(set) var currentBook: Book?
    
    private var playbackTimePublisher = PassthroughSubject<TimeInterval, Never>()

    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimePublisher.eraseToAnyPublisher()
    }
    
    func setCurrentBook(_ value: Book) {
        self.currentBook = value
    }
    
    func loadCurrentAudioFile() throws -> Bool {
        guard let file = currentBook?.audioFiles[currentAudioIndex] else { return false }
        let rate = audioPlayer?.rate
        audioPlayer = try AVAudioPlayer(contentsOf: file)
        audioPlayer?.enableRate = true
        audioPlayer?.delegate = self
        audioPlayer?.rate = rate ?? Constant.defaultRate
        return audioPlayer?.prepareToPlay() ?? false
    }
    
    func play() throws {
        if audioPlayer == nil {
            _ = try loadCurrentAudioFile()
        }
        audioPlayer?.play()
    }
    
    func pause() {
        audioPlayer?.pause()
    }
    
    func next() throws -> Bool {
        guard currentAudioIndex + 1 < currentBook?.audioFiles.count ?? 0 else { return false }
        currentAudioIndex += 1
        return try loadCurrentAudioFile()
    }
    
    func previous() throws -> Bool {
        guard currentAudioIndex > 0 else { return false }
        currentAudioIndex -= 1
        return try loadCurrentAudioFile()
    }
    
    func changePlaybackSpeed(to speed: Double) {
        audioPlayer?.rate = Float(speed)
    }
    
    func startPlaybackTimeUpdates() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.playbackTimePublisher.send(player.currentTime)
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer, player.duration > time else { return }
        player.currentTime = time
    }
    
    func getCoverImage() -> Data? {
        guard let coverImageURL = currentBook?.coverImageFile else { return nil }
        return try? .init(contentsOf: coverImageURL)
    }
    
    func metadata(forIdentifier identifier: AVMetadataIdentifier) async -> String? {
        guard let audioFiles = currentBook?.audioFiles, currentAudioIndex < audioFiles.count else { return nil }
        let asset = AVAsset(url: audioFiles[currentAudioIndex])
        
        do {
            let commonMetadata = try await asset.load(.commonMetadata)
            let metadataItems = AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: identifier)
            if let metadataItem = metadataItems.first {
                let stringValue = try await metadataItem.load(.stringValue)
                return stringValue
            }
            return nil
        } catch {
            return nil
        }
    }
    
    func extractCommonMetadata() async -> String? {
        return await metadata(forIdentifier: .commonIdentifierTitle)
    }
}

extension PlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        playbackTimePublisher.send(player.duration)
    }
}
