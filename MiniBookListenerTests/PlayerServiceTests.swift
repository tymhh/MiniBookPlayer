//
//  PlayerServiceTests.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 18.02.2025.
//

import XCTest
import ComposableArchitecture
import Combine
@testable import MiniBookListener

class PlayerServiceTests: XCTestCase {
    var playerClient: PlayerClient!
    var timePublisher: PassthroughSubject<TimeInterval, Never>!
    
    override func setUp() {
        timePublisher = PassthroughSubject<TimeInterval, Never>()
        playerClient = PlayerClient(
            loadFiles: { _ in },
            setTimePublisher: { _ in },
            loadCurrentAudioFile: { return (true, 10.5, 1) },
            play: { },
            pause: { },
            next: { return (true, 15.0, 2) },
            previous: { return (true, 5.0, 0) },
            changePlaybackSpeed: { speed in
                XCTAssert(speed > 0, "Playback speed should be positive")
            },
            seek: { time in
                XCTAssert(time >= 0, "Seek time should be non-negative")
            },
            metadata: { return "Test Metadata" },
            startPlaybackTimeUpdates: { }
        )
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testLoadFiles() {
        XCTAssertNoThrow(try playerClient.loadFiles([URL(string: "file://test.mp3")!]))
    }
    
    func testSetTimePublisher() {
        XCTAssertNoThrow(try playerClient.setTimePublisher(timePublisher))
    }
    
    func testLoadCurrentAudioFile() {
        let (success, time, index) = try! playerClient.loadCurrentAudioFile()
        XCTAssertTrue(success)
        XCTAssertEqual(time, 10.5)
        XCTAssertEqual(index, 1)
    }
    
    func testNext() {
        let (success, time, index) = try! playerClient.next()
        XCTAssertTrue(success)
        XCTAssertEqual(time, 15.0)
        XCTAssertEqual(index, 2)
    }
    
    func testPrevious() {
        let (success, time, index) = try! playerClient.previous()
        XCTAssertTrue(success)
        XCTAssertEqual(time, 5.0)
        XCTAssertEqual(index, 0)
    }
    
    func testChangePlaybackSpeed() {
        XCTAssertNoThrow(try playerClient.changePlaybackSpeed(1.5))
    }
    
    func testSeek() {
        XCTAssertNoThrow(try playerClient.seek(30.0))
    }
    
    func testMetadata() async throws {
        let metadata = try await playerClient.metadata()
        XCTAssertEqual(metadata, "Test Metadata")
    }
}
