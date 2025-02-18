//
//  AudioManager.swift
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
    var audioFiles: [URL] { get }
    var coverImageFile: URL? { get }
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    
    func loadAudioFiles(from folderName: String) throws -> Bool
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

final class AudioManager: NSObject, PlayerServiceProtocol {
    struct Constant {
        static let defaultRate: Float = 1.0
        static let coverImageName: String = "cover.jpg"
    }
    
    private(set) var audioPlayer: AVAudioPlayer?
    private(set) var currentAudioIndex: Int = 0
    private(set) var audioFiles: [URL] = []
    private(set) var coverImageFile: URL?
    
    private var playbackTimePublisher = PassthroughSubject<TimeInterval, Never>()

    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimePublisher.eraseToAnyPublisher()
    }
    
    func loadAudioFiles(from folderName: String) throws -> Bool {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "\(folderName).bundle") else {
            return false
        }
        audioFiles = urls.filter {
            if isAudioFile(fileURL: $0) {
                return true
            } else if isImageFile(fileURL: $0), $0.lastPathComponent == Constant.coverImageName {
                coverImageFile = $0
                return false
            } else {
                return false
            }
        }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        return try loadCurrentAudioFile()
    }
    
    private func loadCurrentAudioFile() throws -> Bool {
        let file = audioFiles[currentAudioIndex]
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
        guard currentAudioIndex + 1 < audioFiles.count else { return false }
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
        guard let coverImageURL = coverImageFile else { return nil }
        return try? .init(contentsOf: coverImageURL)
    }
    
    func metadata(forIdentifier identifier: AVMetadataIdentifier) async -> String? {
        guard currentAudioIndex < audioFiles.count else { return nil }
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
    
    func isAudioFile(fileURL: URL) -> Bool {
        let audioFileExtensions = ["mp3"]
        let fileExtension = fileURL.pathExtension.lowercased()
        return audioFileExtensions.contains(fileExtension)
    }
    
    func isImageFile(fileURL: URL) -> Bool {
        let audioFileExtensions = ["jpg"]
        let fileExtension = fileURL.pathExtension.lowercased()
        return audioFileExtensions.contains(fileExtension)
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        playbackTimePublisher.send(player.duration)
    }
}
