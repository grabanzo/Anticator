//
//  GroupService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData

/// Servicio para operaciones de OTPGroup que requieren side-effects (Keychain PIN)
/// Para operaciones simples (create, update, reorder), usar modelContext directamente
@MainActor
final class GroupService {
    static let shared = GroupService()
    
    private let keychainService = KeychainService.shared
    private let cryptoService = CryptoService.shared
    
    private init() {}
    
    // MARK: - Delete (requiere limpiar PIN del Keychain)
    
    /// Elimina un grupo y limpia su PIN del Keychain si existe
    func deleteGroup(_ group: OTPGroup, in context: ModelContext) throws {
        // Eliminar PIN del Keychain si existe
        if group.requiresPIN {
            try? keychainService.deleteGroupPINHash(for: group.id)
        }
        
        context.delete(group)
        try context.save()
    }
    
    // MARK: - PIN Management
    
    /// Guarda el PIN para un grupo
    func savePIN(_ pin: String, for group: OTPGroup) throws {
        let hash = cryptoService.hashPIN(pin)
        try keychainService.saveGroupPINHash(hash, for: group.id)
    }
    
    /// Elimina el PIN de un grupo
    func removePIN(for group: OTPGroup) throws {
        try keychainService.deleteGroupPINHash(for: group.id)
    }
    
    /// Verifica si un PIN es correcto para un grupo
    func verifyPIN(_ pin: String, for group: OTPGroup) -> Bool {
        guard let storedHash = try? keychainService.getGroupPINHash(for: group.id) else {
            return false
        }
        return cryptoService.verifyPIN(pin, against: storedHash)
    }
    
    /// Verifica si un grupo tiene PIN configurado
    func hasPIN(for group: OTPGroup) -> Bool {
        (try? keychainService.getGroupPINHash(for: group.id)) != nil
    }
}

