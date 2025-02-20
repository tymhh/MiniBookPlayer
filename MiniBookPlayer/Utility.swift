//
//  Utility.swift
//  MiniBookPlayer
//
//  Created by Tim Hazhyi on 27.11.2023.
//

import Foundation

extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let time = Int(self)
        let minutes = time / 60 % 60
        let seconds = time % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
}

extension Formatter {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
