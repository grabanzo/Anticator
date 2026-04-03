//
//  OTPGroup+UI.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - UI Helpers (MainActor)
extension OTPGroup {
    /// Color del grupo (solo accesible desde MainActor/vistas)
    @MainActor var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}

// MARK: - Predefined Colors for Groups (MainActor para uso en vistas)
@MainActor
extension OTPGroup {
    static var availableColors: [(name: String, hex: String)] {
        Constants.GroupOptions.availableColors()
    }
    
    static var availableIcons: [String] {
        Constants.GroupOptions.availableIcons
    }
}

