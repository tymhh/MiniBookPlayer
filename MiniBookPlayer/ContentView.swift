//
//  ContentView.swift
//  MiniBookPlayer
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
            VStack {
                AsyncImage(url: viewStore.coverImageFile) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, Constant.imagePadding)
                .padding(.bottom, Constant.stackSpacing)
                Text("\(Constant.keyPointPrefix) \(viewStore.currentAudio) / \(viewStore.numberOfAudio)")
                if let audioTitle = viewStore.currentAudioTitle {
                    Text(audioTitle)
                        .font(.title)
                        .padding()
                }
                HStack {
                    Text(viewStore.currentTime.stringFromTimeInterval())
                        .padding(.leading, Constant.textPadding)
                        .monospacedDigit()
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
                        withAnimation {
                            sliderValue = currentTime
                        }
                    }
                    Text(viewStore.duration.stringFromTimeInterval())
                        .padding(.trailing, Constant.textPadding)
                        .monospacedDigit()
                }
                
                Button(action: { viewStore.send(.changePlaybackSpeed)}) {
                    let stringValue = Formatter.decimal.string(from: viewStore.playbackSpeed as NSNumber) ?? "\(viewStore.playbackSpeed)"
                    Text(Constant.speedValuePrefix + stringValue)
                }
                .foregroundColor(.black)
                .padding()
                .background(Color("buttonBackground"))
                .cornerRadius(8)
                .disabled(!viewStore.isBookLoaded)
                
                ActionBar(viewStore: viewStore).padding(.top, Constant.textPadding)
            }.onAppear {
                store.send(.initialiseRemoteCommands(store))
                store.send(.loadBook)
            }.onReceive(viewStore.publisher.errorMessage) { errorMessage in
                showError = errorMessage != nil
            }.overlay { errorOverlay }
            .animation(.easeInOut, value: showError)
            .containerRelativeFrame([.horizontal, .vertical])
            .background(Color("backgroundColor"))
        }
    }
    
    private func hideSnackbar() {
        showError = false
        store.send(.setError(nil))
    }
    
    private var errorOverlay: some View {
        VStack {
            Spacer()
            if showError {
                SnackbarView(message: store.errorMessage ?? Constant.unknownError)
                    .onTapGesture { hideSnackbar() }
                    .onAppear {
                        Task {
                            try await Task.sleep(for: .seconds(3))
                            hideSnackbar()
                        }
                    }
                    .transition(.move(edge: .bottom))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            }
        }
    }
}

