//
//  AppPINService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Servicio para gestionar el PIN de la aplicación (autenticación global)
/// Para el PIN de grupos específicos, usar GroupService
@MainActor
final class AppPINService {
    static let shared = AppPINService()
    
    private let keychainService = KeychainService.shared
    private let cryptoService = CryptoService.shared
    
    private init() {}
    
    // MARK: - Verification
    
    /// Verifica si un PIN es correcto
    func verifyPIN(_ pin: String) -> Bool {
        guard let storedHash = try? keychainService.getPINHash() else {
            return false
        }
        return cryptoService.verifyPIN(pin, against: storedHash)
    }
    
    // MARK: - Management
    
    /// Guarda un nuevo PIN
    func savePIN(_ pin: String) throws {
        let hash = cryptoService.hashPIN(pin)
        try keychainService.savePINHash(hash)
    }
    
    /// Elimina el PIN
    func removePIN() throws {
        try keychainService.deletePINHash()
    }
    
    /// Verifica si hay un PIN configurado
    func hasPIN() -> Bool {
        (try? keychainService.getPINHash()) != nil
    }
}

