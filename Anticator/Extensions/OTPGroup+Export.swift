//
//  OTPGroup+Export.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

// MARK: - Exportable Version
extension OTPGroup {
    struct Exportable: Codable, Sendable {
        let id: UUID
        let name: String
        let iconName: String
        let colorHex: String
        let order: Int
        let requiresPIN: Bool
        let createdAt: Date
        
        // Nota: El PIN hash NO se exporta por seguridad
    }
    
    func toExportable() -> Exportable {
        Exportable(
            id: id,
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            order: order,
            requiresPIN: requiresPIN,
            createdAt: createdAt
        )
    }
}
