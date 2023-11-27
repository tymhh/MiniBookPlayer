//
//  ContentView.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 24.11.2023.
//

import SwiftUI
import ComposableArchitecture

#Preview {
    let environment = AudioPlayerEnvironment(audioManager: AudioManager(), mainQueue: .main)
    
    return AudioPlayerView(store: Store(initialState: AudioPlayerFeature.State()) {
        AudioPlayerFeature(environment: environment, bundleName: "Fables by Glibov")
    })
}

struct AudioPlayerView: View {
    var store: Store<AudioPlayerState, AudioPlayerAction>
    @State private var sliderValue: TimeInterval = 0
    @State private var isSliderEditing: Bool = false
    @State private var showError: Bool = false

    struct Constant {
        static let unknownError: String = "Unknown Error"
        static let keyPointPrefix: String = "KEY POINT"
        static let speedValuePrefix: String = "Speed x"
        static let imagePadding: CGFloat = 64
        static let textPadding: CGFloat = 16
        static let buttonPadding: CGFloat = 32
        static let stackSpacing: CGFloat = 20
    }
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                VStack {
                    Spacer()
                    if showError {
                        SnackbarView(message: viewStore.errorMessage ?? Constant.unknownError)
                            .onTapGesture {
                                hideSnackbar()
                            }
                    }
                }
                VStack {
                    if let image = viewStore.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.leading, Constant.imagePadding)
                            .padding(.trailing, Constant.imagePadding)
                    }
                    Text("\(Constant.keyPointPrefix) \(viewStore.currentAudio) / \(viewStore.numberOfAudio)")
                    if let audioTitle = viewStore.currentAudioTitle {
                        Text(audioTitle)
                            .font(.title)
                            .padding()
                    }
                    HStack {
                        Text(viewStore.currentTime.stringFromTimeInterval())
                            .padding(.leading, Constant.textPadding)
                        Slider(
                            value: $sliderValue,
                            in: 0...viewStore.duration,
                            onEditingChanged: { editing in
                                isSliderEditing = editing
                                guard !editing else { return }
                                viewStore.send(.seek(sliderValue))
                            }
                        ).onAppear {
                            sliderValue = viewStore.currentTime
                        }.onReceive(viewStore.publisher.currentTime) { currentTime in
                            guard !isSliderEditing else { return }
                            sliderValue = currentTime
                        }
                        Text(viewStore.duration.stringFromTimeInterval())
                            .padding(.trailing, Constant.textPadding)
                    }
                    
                    Button(action: { viewStore.send(.changePlaybackSpeed)}) {
                        let stringValue = Formatter.decimal.string(from: viewStore.playbackSpeed as NSNumber) ?? "\(viewStore.playbackSpeed)"
                        Text(Constant.speedValuePrefix + stringValue)
                    }.padding(.bottom, Constant.buttonPadding)
                    
                    HStack(spacing: Constant.stackSpacing) {
                        ActionButton(imageName: "backward.end",
                                     action: { viewStore.send(.previousButtonTapped) })
                        ActionButton(imageName: "gobackward.5",
                                     action: { viewStore.send(.backwardButtonTapped) })
                        ActionButton(imageName: viewStore.isPlaying ? "pause.circle" : "play.circle",
                                     action: { viewStore.send(.playPauseButtonTapped) })
                        ActionButton(imageName: "goforward.10",
                                     action: { viewStore.send(.forwardButtonTapped) })
                        ActionButton(imageName: "forward.end",
                                     action: { viewStore.send(.nextButtonTapped) })
                    }
                }
            }.onAppear {
                store.send(.loadAudio)
            }.onReceive(viewStore.publisher.errorMessage) { errorMessage in
                showError = errorMessage != nil
            }
            .animation(.easeInOut, value: showError)
        }
    }
    
    private func hideSnackbar() {
        showError = false
        store.send(.setError(nil))
    }
}

