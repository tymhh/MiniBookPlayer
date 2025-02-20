//
//  SnackbarView.swift
//  MiniBookPlayer
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import SwiftUI

struct SnackbarView: View {
    let message: String
    var body: some View {
        Text(message)
            .foregroundColor(.black)
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 5)
            .padding()
    }
}
