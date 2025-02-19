//
//  BooksClient.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 18.02.2025.
//
import Foundation
import ComposableArchitecture

enum BooksClientError: String, LocalizedError {
    case bookFileNonExist
    case bookHasNoFiles
    
    var errorDescription: String? { self.rawValue }
}

@DependencyClient
struct BooksClient {
    struct Constant {
        static let coverImageName: String = "cover.jpg"
    }
    
    var loadBook: @Sendable (String) throws -> Result<Book, Error>
}

extension BooksClient: DependencyKey {
    static let liveValue = Self(
        loadBook: { folderName in
            guard let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "\(folderName).bundle") else {
                return .failure(BooksClientError.bookFileNonExist)
            }
            var coverImageFile: URL?
            let audioFiles = urls.filter {
                if isAudioFile(fileURL: $0) {
                    return true
                } else if isImageFile(fileURL: $0), $0.lastPathComponent == Constant.coverImageName {
                    coverImageFile = $0
                    return false
                } else {
                    return false
                }
            }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            
            guard !audioFiles.isEmpty else { return .failure(BooksClientError.bookHasNoFiles) }
            return .success(Book(title: folderName,
                                 audioFiles: audioFiles,
                                 coverImageFile: coverImageFile)
            )
        }
    )
    
    static let testValue = Self(
        loadBook: { folderName in
            return .success(.init(title: folderName, audioFiles: [URL(string: "file1.mp3")!], coverImageFile: nil))
        }
    )
    
    static private func isAudioFile(fileURL: URL) -> Bool {
        let audioFileExtensions = ["mp3", "wav", "m4a"]
        let fileExtension = fileURL.pathExtension.lowercased()
        return audioFileExtensions.contains(fileExtension)
    }
    
    static private func isImageFile(fileURL: URL) -> Bool {
        let imageFileExtensions = ["jpg", "png"]
        let fileExtension = fileURL.pathExtension.lowercased()
        return imageFileExtensions.contains(fileExtension)
    }
}

extension DependencyValues {
  var booksClient: BooksClient {
    get { self[BooksClient.self] }
    set { self[BooksClient.self] = newValue }
  }
}
