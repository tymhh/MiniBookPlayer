//
//  ContentView.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 24.11.2023.
//

import SwiftUI
import ComposableArchitecture

#Preview {
    let environment = AudioPlayerEnvironment(bundleName: "Fables by Glibov")
    
    AudioPlayerView(store: Store(initialState: AudioPlayerFeature.State()) {
        AudioPlayerFeature(environment: environment)
    })
}

struct AudioPlayerView: View {
    var store: StoreOf<AudioPlayerFeature>
    @State private var sliderValue: TimeInterval = 0
    @State private var isSliderEditing: Bool = false
    @State private var showError: Bool = false

    struct Constant {
        static let unknownError: String = "Unknown Error"
        static let keyPointPrefix: String = "KEY POINT"
        static let speedValuePrefix: String = "Speed x"
        static let imagePadding: CGFloat = 64
        static let textPadding: CGFloat = 16
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
                            .padding(.bottom, Constant.stackSpacing)
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
                    }
                    .foregroundColor(.black)
                    .padding()
                    .background(Color("buttonBackground"))
                    .cornerRadius(8)
                    
                    ActionBar(viewStore: viewStore).padding(.top, Constant.textPadding)
                }
            }.onAppear {
                store.send(.loadBook)
            }.onReceive(viewStore.publisher.errorMessage) { errorMessage in
                showError = errorMessage != nil
            }
            .animation(.easeInOut, value: showError)
        }.background(Color("backgroundColor"))
    }
    
    private func hideSnackbar() {
        showError = false
        store.send(.setError(nil))
    }
}

