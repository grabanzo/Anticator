//
//  OTPAccountService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData

/// Servicio para operaciones de OTPAccount que requieren side-effects (Keychain)
/// Para operaciones simples (update, reorder), usar modelContext directamente
@MainActor
final class OTPAccountService {
    static let shared = OTPAccountService()
    
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    // MARK: - Create (requiere Keychain)
    
    /// Crea una nueva cuenta OTP y guarda el secreto en Keychain
    func createAccount(
        in context: ModelContext,
        issuer: String,
        accountName: String,
        secret: String,
        type: OTPType = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: Int = 0,
        iconName: String? = nil,
        groupId: UUID? = nil
    ) throws -> OTPAccount {
        let id = UUID()
        
        // Guardar secreto en Keychain primero
        try keychainService.saveSecret(secret, for: id)
        
        // Calcular orden (al final de la lista)
        let descriptor = FetchDescriptor<OTPAccount>(
            predicate: #Predicate { $0.deletedAt == nil }
        )
        let accounts = try context.fetch(descriptor)
        let maxOrder = accounts.map(\.order).max() ?? -1
        
        // Crear cuenta
        let account = OTPAccount(
            id: id,
            issuer: issuer,
            accountName: accountName,
            secretKeyRef: id.uuidString,
            type: type,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter,
            iconName: iconName,
            groupId: groupId,
            order: maxOrder + 1
        )
        
        context.insert(account)
        try context.save()
        
        return account
    }
    
    /// Crea una cuenta desde una URI parseada
    func createAccount(
        in context: ModelContext,
        from parsedURI: ParsedOTPURI,
        groupId: UUID? = nil
    ) throws -> OTPAccount {
        try createAccount(
            in: context,
            issuer: parsedURI.issuer,
            accountName: parsedURI.accountName,
            secret: parsedURI.secret,
            type: parsedURI.type,
            algorithm: parsedURI.algorithm,
            digits: parsedURI.digits,
            period: parsedURI.period,
            counter: parsedURI.counter,
            groupId: groupId
        )
    }
    
    // MARK: - Delete (requiere Keychain)
    
    /// Elimina una cuenta (soft delete) y limpia el secreto del Keychain
    func deleteAccount(_ account: OTPAccount, in context: ModelContext) throws {
        account.deletedAt = Date()
        account.updatedAt = Date()
        try context.save()
        
        // Eliminar secreto del Keychain
        try? keychainService.deleteSecret(for: account.id)
    }
    
    /// Elimina una cuenta permanentemente y limpia el secreto del Keychain
    func permanentlyDeleteAccount(_ account: OTPAccount, in context: ModelContext) throws {
        // Eliminar secreto del Keychain
        try? keychainService.deleteSecret(for: account.id)
        
        context.delete(account)
        try context.save()
    }
    
    // MARK: - Import Support (requiere Keychain)
    
    /// Inserta una cuenta ya construida y guarda su secreto (usado para importación)
    func insertAccount(_ account: OTPAccount, secret: String, in context: ModelContext) throws {
        try keychainService.saveSecret(secret, for: account.id)
        context.insert(account)
    }
    
    /// Actualiza el secreto de una cuenta existente en Keychain
    func updateSecret(_ secret: String, for account: OTPAccount) throws {
        try keychainService.saveSecret(secret, for: account.id)
    }
    
    // MARK: - Secrets
    
    /// Obtiene el secreto de una cuenta desde el Keychain
    func getSecret(for account: OTPAccount) throws -> String {
        try keychainService.getSecret(for: account.id)
    }
    
    /// Obtiene el secreto de una cuenta por ID desde el Keychain
    func getSecret(for accountId: UUID) throws -> String {
        try keychainService.getSecret(for: accountId)
    }
}

