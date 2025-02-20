//
//  AudioPlayerFeature.swift
//  MiniBookPlayer
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import ComposableArchitecture
import SwiftUI
import MediaPlayer
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
        case initialiseRemoteCommands(StoreOf<AudioPlayerFeature>)
        case loadBook
        case loadAudio(URL?, Int)
        case audioLoaded(TimeInterval, Int)
        case metadataResolved(String?)
        case setError(Error?)
        case playPauseButtonTapped(Bool)
        case backwardButtonTapped
        case forwardButtonTapped
        case previousButtonTapped
        case nextButtonTapped
        case seek(TimeInterval)
        case changePlaybackSpeed
        case updateCurrentTime(TimeInterval)
        case updateNowPlayingInfo
    }
    
    @Dependency(\.booksClient) var booksClient
    @Dependency(\.playerClient) var playerClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .initialiseRemoteCommands(let store):
                initialiseRemoteCommands(store)
                return .none
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
                playerClient.startPlaybackTimeUpdates()
                state.duration = duration
                state.currentAudio = index + 1
                return .run { send in
                    let title = try await playerClient.metadata()
                    await send(.metadataResolved(title))
                }
            case .playPauseButtonTapped(let force):
                do {
                    let _ = try playerClient.play()
                    force ? state.isPlaying = true : state.isPlaying.toggle()
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
                    return .run { send in
                        await send(.audioLoaded(duration, index))
                        await send(.playPauseButtonTapped(true))
                    }
                } catch {
                    return .run { send in
                        await send(.setError(error))
                    }
                }
            case .nextButtonTapped:
                do {
                    let (duration, index) = try playerClient.next()
                    return .run { send in
                        await send(.audioLoaded(duration, index))
                        await send(.playPauseButtonTapped(true))
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
                return .run { send in
                    await send(.updateNowPlayingInfo)
                }
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
            case .updateNowPlayingInfo:
                var nowPlayingInfo: [String: Any] = [
                    MPMediaItemPropertyPlaybackDuration: state.duration,
                    MPNowPlayingInfoPropertyElapsedPlaybackTime: state.currentTime,
                    MPNowPlayingInfoPropertyPlaybackRate: state.playbackSpeed
                ]
                state.currentAudioTitle.map { nowPlayingInfo[MPMediaItemPropertyTitle] = $0 }
                if let url = state.coverImageFile,
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] =
                    MPMediaItemArtwork(boundsSize: image.size) { size in image }
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                return .none
            }
        }
    }
    
    fileprivate func initialiseRemoteCommands(_ store: StoreOf<AudioPlayerFeature>) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            store.send(.playPauseButtonTapped(false))
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { _ in
            store.send(.nextButtonTapped)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { _ in
            store.send(.previousButtonTapped)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            store.send(.seek(event.positionTime))
            return .success
        }
    }
}
