//
//  AuthenticationViewModel.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class AuthenticationViewModel {
    var isAuthenticating = false
    var error: String?
    
    private let biometricService = BiometricService.shared
    
    /// Autentica con biometría y devuelve true si fue exitoso
    func authenticateWithBiometrics() async -> Bool {
        isAuthenticating = true
        error = nil
        defer { isAuthenticating = false }
        
        let result = await biometricService.authenticate(reason: "Desbloquear \(Constants.App.name)")
        
        switch result {
        case .success:
            return true
        case .failure(let biometricError):
            switch biometricError {
            case .userCancelled, .userFallback:
                // No mostrar error si el usuario canceló o quiere usar PIN
                break
            default:
                error = biometricError.localizedDescription
            }
            return false
        }
    }
}

