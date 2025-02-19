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
    let environment = AudioPlayerEnvironment(bundleName: "Fables by Glibov")
    var body: some Scene {
        WindowGroup {
            AudioPlayerView(store: Store(initialState: AudioPlayerFeature.State()) {
                AudioPlayerFeature(environment: environment)
            })
        }
    }
}
