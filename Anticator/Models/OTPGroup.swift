//
//  OTPGroup.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class OTPGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var order: Int
    var requiresPIN: Bool
    var createdAt: Date
    
    // El PIN hash se guarda en Keychain, no aquí
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "person.fill",
        colorHex: String = "007AFF",
        order: Int = 0,
        requiresPIN: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.order = order
        self.requiresPIN = requiresPIN
        self.createdAt = Date()
    }
}
