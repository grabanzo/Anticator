//
//  OTPAccount+UI.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Extensión de OTPAccount para lógica de presentación (UI)
/// Separada del modelo para mantener responsabilidades claras
@MainActor
extension OTPAccount {
    /// Nombre del icono resuelto para mostrar en la UI
    /// Usa el icono personalizado si existe, o mapea automáticamente desde el issuer
    var resolvedIconName: String {
        if let iconName = iconName, !iconName.isEmpty {
            return iconName
        }
        return ServiceIconMapper.iconName(for: issuer)
    }
}

