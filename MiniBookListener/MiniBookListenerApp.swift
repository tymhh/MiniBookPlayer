//
//  MiniBookListenerApp.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 24.11.2023.
//

import SwiftUI
import ComposableArchitecture

@main
struct MiniBookListenerApp: App {
    struct Constant {
        static let bundleName: String = "Fables by Glibov"
    }
    
    let environment = AudioPlayerEnvironment(audioManager: AudioManager(), mainQueue: .main)
    var body: some Scene {
        WindowGroup {
            AudioPlayerView(store: Store(initialState: AudioPlayerFeature.State()) {
                AudioPlayerFeature(environment: environment, bundleName: Constant.bundleName)
            })
        }
    }
}
