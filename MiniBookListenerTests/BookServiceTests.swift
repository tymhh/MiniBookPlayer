//
//  BookServiceTests.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 18.02.2025.
//


import XCTest
import AVFoundation
import ComposableArchitecture
@testable import MiniBookListener

class BookServiceTests: XCTestCase {
    @Dependency(\.booksClient) var booksClient

    override func setUp() {
        super.setUp()
        
    }

    override func tearDown() {
        super.tearDown()
    }

    func testLoadBook_Success() throws {
        let result = try booksClient.loadBook("MockBook")
        
        switch result {
        case .success(let book):
            XCTAssertEqual(book.title, "MockBook")
            XCTAssertEqual(book.audioFiles.count, 1)
            XCTAssertNil(book.coverImageFile)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
}
