//
//  BiometricService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import LocalAuthentication

/// Servicio para autenticación biométrica (Face ID / Touch ID)
/// Thread-safe y accesible desde cualquier contexto
final class BiometricService: Sendable {
    static let shared = BiometricService()
    
    private init() {}
    
    /// Tipo de biometría disponible en el dispositivo
    enum BiometricType {
        case none
        case faceID
        case touchID
        
        var displayName: String {
            switch self {
            case .none: return String(localized: "No disponible")
            case .faceID: return String(localized: "Face ID")
            case .touchID: return String(localized: "Touch ID")
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return "lock.slash"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            }
        }
    }
    
    /// Detecta el tipo de biometría disponible
    var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID // Tratamos OpticID como FaceID para simplificar
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Verifica si la biometría está disponible
    var isBiometricAvailable: Bool {
        availableBiometricType != .none
    }
    
    /// Autentica al usuario con biometría
    func authenticate(reason: String = String(localized: "Desbloquear Anticator")) async -> Result<Void, BiometricError> {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                return .success(())
            } else {
                return .failure(.failed)
            }
        } catch let error as NSError {
            return .failure(mapError(error))
        }
    }
    
    /// Autentica con biometría o passcode del dispositivo como fallback
    func authenticateWithPasscodeFallback(reason: String = String(localized: "Desbloquear Anticator")) async -> Result<Void, BiometricError> {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                return .success(())
            } else {
                return .failure(.failed)
            }
        } catch let error as NSError {
            return .failure(mapError(error))
        }
    }
    
    private func mapError(_ error: NSError) -> BiometricError {
        switch error.code {
        case LAError.authenticationFailed.rawValue:
            return .failed
        case LAError.userCancel.rawValue:
            return .userCancelled
        case LAError.userFallback.rawValue:
            return .userFallback
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.biometryLockout.rawValue:
            return .lockout
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Errors
enum BiometricError: LocalizedError, Sendable {
    case notAvailable
    case notEnrolled
    case failed
    case userCancelled
    case userFallback
    case lockout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "La autenticación biométrica no está disponible."
        case .notEnrolled:
            return "No hay datos biométricos registrados."
        case .failed:
            return "La autenticación falló."
        case .userCancelled:
            return "Autenticación cancelada."
        case .userFallback:
            return "Usuario solicitó método alternativo."
        case .lockout:
            return "Biometría bloqueada. Usa el código del dispositivo."
        case .unknown(let message):
            return message
        }
    }
}

