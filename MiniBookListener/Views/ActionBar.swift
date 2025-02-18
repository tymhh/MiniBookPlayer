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
            ActionButton(
                imageName: "backward.end.fill",
                action: { viewStore.send(.previousButtonTapped) }
            ).scaleEffect(Constant.smallScale)
            ActionButton(
                imageName: "gobackward.5",
                action: { viewStore.send(.backwardButtonTapped) }
            ).scaleEffect(Constant.midScale)
            
            let imageName = viewStore.isPlaying ? "pause.fill" : "play.fill"
            ActionButton(
                imageName: imageName,
                action: { viewStore.send(.playPauseButtonTapped) }
            )
            
            ActionButton(
                imageName: "goforward.10",
                action: { viewStore.send(.forwardButtonTapped) }
            ).scaleEffect(Constant.midScale)
            ActionButton(
                imageName: "forward.end.fill",
                action: { viewStore.send(.nextButtonTapped) }
            ).scaleEffect(Constant.smallScale)
        }
    }
}
