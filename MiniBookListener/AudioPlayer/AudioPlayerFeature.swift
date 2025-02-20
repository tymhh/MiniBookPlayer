//
//  AudioPlayerFeature.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import ComposableArchitecture
import SwiftUI
import AVFoundation
import Combine

struct AudioPlayerEnvironment {
    let bundleName: String
    var mainQueue: AnySchedulerOf<DispatchQueue> = .main
    var playbackTimePublisher = PassthroughSubject<TimeInterval, Never>()
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimePublisher.eraseToAnyPublisher()
    }
}

struct CurrentTimeUpdaterID: Hashable {}

@Reducer
struct AudioPlayerFeature: Reducer {
    let environment: AudioPlayerEnvironment
    
    struct Constant {
        static let backwardTime: TimeInterval = 5.0
        static let forwardTime: TimeInterval = 10.0
        static let maxSpeed: Float = 2.0
        static let speedStep: Float = 0.25
        static let defaultSpeed: Float = 1.0
    }
    
    @ObservableState
    struct State: Equatable {
        var isPlaying: Bool = false
        var isBookLoaded: Bool = false
        var currentTime: TimeInterval = 0
        var duration: TimeInterval = 0
        var playbackSpeed: Float = 1.0
        var coverImageFile: URL?
        var currentAudioTitle: String?
        var currentAudio: Int = 1
        var numberOfAudio: Int = 0
        var errorMessage: String?
    }
    
    enum Action {
        case loadBook
        case loadAudio(URL?, Int)
        case audioLoaded(TimeInterval, Int)
        case metadataResolved(String?)
        case setError(Error?)
        case playPauseButtonTapped
        case backwardButtonTapped
        case forwardButtonTapped
        case previousButtonTapped
        case nextButtonTapped
        case seek(TimeInterval)
        case changePlaybackSpeed
        case updateCurrentTime(TimeInterval)
    }
    
    @Dependency(\.booksClient) var booksClient
    @Dependency(\.playerClient) var playerClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadBook:
                return .run { send in
                    let result = try booksClient.loadBook(environment.bundleName)
                    switch result {
                    case .success(let book):
                        try playerClient.loadFiles(book.audioFiles)
                        try playerClient.setTimePublisher(environment.playbackTimePublisher)
                        let cover = book.coverImageFile
                        await send(.loadAudio(cover, book.audioFiles.count))
                    case .failure(let error):
                        await send(.setError(error))
                    }
                }
            case .loadAudio(let cover, let count):
                state.isBookLoaded = true
                state.coverImageFile = cover
                state.numberOfAudio = count
                return .run { send in
                    let (duration, index) = try playerClient.loadCurrentAudioFile()
                    await send(.audioLoaded(duration, index))
                }
            case .audioLoaded(let duration, let index):
                state.duration = duration
                state.currentAudio = index + 1
                return .run { send in
                    let title = try await playerClient.metadata()
                    await send(.metadataResolved(title))
                }
            case .playPauseButtonTapped:
                do {
                    let _ = try playerClient.play()
                    state.isPlaying.toggle()
                    playerClient.startPlaybackTimeUpdates()
                    if state.isPlaying {
                        return .publisher {
                            environment.currentTimePublisher
                                .receive(on: environment.mainQueue)
                                .map(Action.updateCurrentTime)
                        }.cancellable(id: CurrentTimeUpdaterID(), cancelInFlight: true)
                    } else {
                        playerClient.pause()
                        return .cancel(id: CurrentTimeUpdaterID())
                    }
                } catch {
                    return .run { send in
                        await send(.setError(error))
                    }
                }
            case .backwardButtonTapped:
                let newTime = state.currentTime > Constant.backwardTime ? state.currentTime - Constant.backwardTime : .zero
                state.currentTime = newTime
                return .run { send in
                    try playerClient.seek(newTime)
                }
            case .forwardButtonTapped:
                if state.currentTime < state.duration - Constant.forwardTime {
                    let newTime = state.currentTime + Constant.forwardTime
                    state.currentTime = newTime
                    return .run { send in
                        try playerClient.seek(newTime)
                    }
                } else {
                    return .run { send in await send(.nextButtonTapped) }
                }
            case .previousButtonTapped:
                do {
                    let (duration, index) = try playerClient.previous()
                    state.isPlaying = false
                    return .run { send in
                        await send(.audioLoaded(duration, index))
                        await send(.playPauseButtonTapped)
                    }
                } catch {
                    return .run { send in
                        await send(.setError(error))
                    }
                }
            case .nextButtonTapped:
                do {
                    let (duration, index) = try playerClient.next()
                    state.isPlaying = false
                    return .run { send in
                        await send(.audioLoaded(duration, index))
                        await send(.playPauseButtonTapped)
                    }
                } catch {
                    return .run { send in
                        await send(.setError(error))
                    }
                }
            case .seek(let time):
                state.currentTime = time
                return .run { send in
                    try playerClient.seek(time)
                }
            case .changePlaybackSpeed:
                let newSpeed = state.playbackSpeed >= Constant.maxSpeed ? Constant.defaultSpeed : state.playbackSpeed + Constant.speedStep
                state.playbackSpeed = newSpeed
                return .run { send in
                    try playerClient.changePlaybackSpeed(newSpeed)
                }
            case .metadataResolved(let title):
                state.currentAudioTitle = title
                return .none
            case .updateCurrentTime(let newTime):
                if newTime == state.duration {
                    return .run { send in await send(.nextButtonTapped) }
                } else {
                    state.currentTime = newTime
                    return .none
                }
            case .setError(let error):
                if error is BooksClientError {
                    state.isBookLoaded = false
                }
                state.errorMessage = error?.localizedDescription
                return .none
            }
        }
    }
}
