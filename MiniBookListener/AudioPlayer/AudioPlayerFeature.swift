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
    var audioManager: AudioManager
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

struct AudioPlayerState: Equatable {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackSpeed: Double = 1.0
    var coverImage: UIImage?
    var currentAudioTitle: String?
    var currentAudio: Int = 1
    var numberOfAudio: Int = 0
    var errorMessage: String?
}

enum AudioPlayerAction {
    case loadAudio
    case audioLoaded(Bool)
    case metadataResolved(String?)
    case setError(String?)
    case playPauseButtonTapped
    case backwardButtonTapped
    case forwardButtonTapped
    case previousButtonTapped
    case nextButtonTapped
    case seek(TimeInterval)
    case changePlaybackSpeed
    case updateCurrentTime(TimeInterval)
}

struct CurrentTimeUpdaterID: Hashable {}

@Reducer
struct AudioPlayerFeature {
    let environment: AudioPlayerEnvironment
    let bundleName: String
    
    struct Constant {
        static let backwardTime: TimeInterval = 5.0
        static let forwardTime: TimeInterval = 10.0
        static let maxSpeed: Double = 2.0
        static let speedStep: Double = 0.25
        static let defaultSpeed: Double = 1.0
    }
    
    var body: some Reducer<AudioPlayerState, AudioPlayerAction> {
        Reduce { state, action in
            switch action {
            case .playPauseButtonTapped:
                do {
                    try environment.audioManager.play()
                } catch {
                    return .run { send in
                        await send.callAsFunction(.setError(error.localizedDescription))
                    }
                }
                state.isPlaying.toggle()
                environment.audioManager.startPlaybackTimeUpdates()
                if state.isPlaying {
                    return .publisher {
                        environment.audioManager.currentTimePublisher
                            .receive(on: environment.mainQueue)
                            .map(AudioPlayerAction.updateCurrentTime)
                    }.cancellable(id: CurrentTimeUpdaterID(), cancelInFlight: true)
                } else {
                    environment.audioManager.pause()
                    return .cancel(id: CurrentTimeUpdaterID())
                }
            case .backwardButtonTapped:
                let newTime = state.currentTime > Constant.backwardTime ? state.currentTime - Constant.backwardTime : .zero
                state.currentTime = newTime
                environment.audioManager.seek(to: newTime)
                return .none
            case .forwardButtonTapped:
                if state.currentTime < state.duration - Constant.forwardTime {
                    let newTime = state.currentTime + Constant.forwardTime
                    state.currentTime = newTime
                    environment.audioManager.seek(to: newTime)
                    return .none
                } else {
                    return .run { send in await send.callAsFunction(.nextButtonTapped) }
                }
            case .previousButtonTapped:
                do {
                    let isLoaded = try environment.audioManager.previous()
                    if isLoaded { state.isPlaying = false }
                    return .run { send in
                        if isLoaded {
                            try environment.audioManager.play()
                            await send.callAsFunction(.audioLoaded(true))
                            await send.callAsFunction(.playPauseButtonTapped)
                        } else {
                            await send.callAsFunction(.setError("Previous audio can't be loaded"))
                        }
                    }
                } catch {
                    return .run { send in
                        await send.callAsFunction(.setError(error.localizedDescription))
                    }
                }
            case .nextButtonTapped:
                do {
                    let isLoaded = try environment.audioManager.next()
                    if isLoaded { state.isPlaying = false }
                    return .run { send in
                        if isLoaded {
                            try environment.audioManager.play()
                            await send.callAsFunction(.audioLoaded(true))
                            await send.callAsFunction(.playPauseButtonTapped)
                        } else {
                            await send.callAsFunction(.setError("Next audio can't be loaded"))
                        }
                    }
                } catch {
                    return .run { send in
                        await send.callAsFunction(.setError(error.localizedDescription))
                    }
                }
            case .seek(let time):
                state.currentTime = time
                environment.audioManager.seek(to: time)
                return .none
            case .changePlaybackSpeed:
                let newSpeed = state.playbackSpeed >= Constant.maxSpeed ? Constant.defaultSpeed : state.playbackSpeed + Constant.speedStep
                state.playbackSpeed = newSpeed
                environment.audioManager.changePlaybackSpeed(to: newSpeed)
                return .none
            case .loadAudio:
                return .run { send in
                    let isSuccess = try environment.audioManager.loadAudioFiles(from: bundleName)
                    await send.callAsFunction(.audioLoaded(isSuccess))
                }
            case .audioLoaded(let isSuccess):
                if isSuccess {
                    state.duration = environment.audioManager.audioPlayer?.duration ?? 0
                    state.coverImage = environment.audioManager.getCoverImage().flatMap { UIImage(data: $0) }
                    state.currentAudio = environment.audioManager.currentAudioIndex + 1
                    state.numberOfAudio = environment.audioManager.audioFiles.count
                }
                return .run { send in
                    let title = await environment.audioManager.extractCommonMetadata()
                    await send.callAsFunction(.metadataResolved(title))
                }
            case .metadataResolved(let title):
                state.currentAudioTitle = title
                return .none
            case .updateCurrentTime(let newTime):
                if newTime == state.duration {
                    return .run { send in await send.callAsFunction(.nextButtonTapped) }
                } else {
                    state.currentTime = newTime
                    return .none
                }
            case .setError(let message):
                state.errorMessage = message
                return .none
            }
        }
    }
}
