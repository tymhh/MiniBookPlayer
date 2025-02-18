//
//  PlayerServiceTests.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 18.02.2025.
//

import XCTest
@testable import MiniBookListener

class PlayerServiceTests: XCTestCase {
    var mockAudioManager: MockPlayerService!

    override func setUp() {
        super.setUp()
        mockAudioManager = MockPlayerService()
    }

    override func tearDown() {
        mockAudioManager = nil
        super.tearDown()
    }

    func testLoadAudioFiles() throws {
        let result = try mockAudioManager.loadAudioFiles(from: "TestFolder")
        XCTAssertTrue(result)
        XCTAssertTrue(mockAudioManager.didLoadAudioFiles)
    }
    
    func testPlayAudio() throws {
        try mockAudioManager.play()
        XCTAssertTrue(mockAudioManager.isPlaying)
    }
    
    func testPauseAudio() {
        mockAudioManager.pause()
        XCTAssertFalse(mockAudioManager.isPlaying)
    }

    func testNextAudio() throws {
        mockAudioManager.audioFiles = [URL(string: "file1.mp3")!, URL(string: "file2.mp3")!]
        let result = try mockAudioManager.next()
        XCTAssertTrue(result)
        XCTAssertEqual(mockAudioManager.currentAudioIndex, 1)
    }
    
    func testPreviousAudio() throws {
        mockAudioManager.audioFiles = [URL(string: "file1.mp3")!, URL(string: "file2.mp3")!]
        mockAudioManager.currentAudioIndex = 1
        let result = try mockAudioManager.previous()
        XCTAssertTrue(result)
        XCTAssertEqual(mockAudioManager.currentAudioIndex, 0)
    }
    
    func testPreviousAtFirstAudio() throws {
        mockAudioManager.currentAudioIndex = 0
        let result = try mockAudioManager.previous()
        XCTAssertTrue(result)
        XCTAssertEqual(mockAudioManager.currentAudioIndex, 0)
    }

    func testChangePlaybackSpeed() {
        mockAudioManager.changePlaybackSpeed(to: 1.5)
        XCTAssertEqual(mockAudioManager.playbackSpeed, 1.5)
    }
    
    func testSeekAudio() {
        let seekTime: TimeInterval = 10.0
        mockAudioManager.seek(to: seekTime)
        XCTAssertEqual(mockAudioManager.seekTime, seekTime)
    }
    
    func testGetCoverImageReturnsNil() {
        let coverImage = mockAudioManager.getCoverImage()
        XCTAssertNil(coverImage)
    }

    func testRetrieveMetadata() async {
        let metadata = await mockAudioManager.metadata(forIdentifier: .commonIdentifierTitle)
        XCTAssertEqual(metadata, "Mock Metadata")
    }
}
