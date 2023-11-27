//
//  ActionButton.swift
//  MiniBookListener
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import SwiftUI

struct ActionButton: View {
    let imageName: String
    let size: CGFloat = 32
    let action: () -> Void
    
    var body: some View {
        Button(action: { action() }) {
            Image(systemName: imageName)
                .resizable()
                .frame(width: size, height: size, alignment: .center)
                .tint(Color.black)
        }
    }
}
