//
//  AppBootstrapService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData

/// Servicio responsable de la inicialización de datos al arrancar la app
@MainActor
enum AppBootstrapService {
    
    /// Inicializa los datos necesarios para el primer arranque
    /// - Parameter context: El contexto de SwiftData
    static func initialize(context: ModelContext) {
        createDefaultGroupIfNeeded(in: context)
    }
    
    // MARK: - Private
    
    private static func createDefaultGroupIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<OTPGroup>()
        let groups = try? context.fetch(descriptor)
        
        guard groups?.isEmpty ?? true else { return }
        
        // Crear grupo por defecto - operación simple, modelContext directo
        let defaultGroup = OTPGroup(
            name: Constants.DefaultGroup.name,
            iconName: Constants.DefaultGroup.iconName,
            colorHex: Constants.DefaultGroup.colorHex,
            order: 0
        )
        context.insert(defaultGroup)
        try? context.save()
    }
}
