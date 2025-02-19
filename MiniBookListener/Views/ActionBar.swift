//
//  ActionBar.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import SwiftUI
import ComposableArchitecture

struct ActionBar: View {
    struct Constant {
        static let stackSpacing: CGFloat = 20
        static let smallScale: CGFloat = 0.6
        static let midScale: CGFloat = 0.8
    }
    
    var viewStore: ViewStoreOf<AudioPlayerFeature>
    
    var body: some View {
        HStack(spacing: Constant.stackSpacing) {
            let isBackwardDisabled = viewStore.currentAudio - 1 <= 0
            ActionButton(
                imageName: "backward.end.fill",
                disabled: !viewStore.isBookLoaded || isBackwardDisabled,
                action: { viewStore.send(.previousButtonTapped) }
            ).scaleEffect(Constant.smallScale)
            ActionButton(
                imageName: "gobackward.5",
                disabled: !viewStore.isBookLoaded,
                action: { viewStore.send(.backwardButtonTapped) }
            ).scaleEffect(Constant.midScale)
            
            let imageName = viewStore.isPlaying ? "pause.fill" : "play.fill"
            ActionButton(
                imageName: imageName,
                disabled: !viewStore.isBookLoaded,
                action: { viewStore.send(.playPauseButtonTapped) }
            )
            
            ActionButton(
                imageName: "goforward.10",
                disabled: !viewStore.isBookLoaded,
                action: { viewStore.send(.forwardButtonTapped) }
            ).scaleEffect(Constant.midScale)
            let isForwardDisabled = viewStore.currentAudio == viewStore.numberOfAudio
            ActionButton(
                imageName: "forward.end.fill",
                disabled: !viewStore.isBookLoaded || isForwardDisabled,
                action: { viewStore.send(.nextButtonTapped) }
            ).scaleEffect(Constant.smallScale)
        }
    }
}
