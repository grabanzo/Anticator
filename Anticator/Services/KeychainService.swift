//
//  KeychainService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import Security

/// Servicio para almacenamiento seguro en Keychain
/// Thread-safe y accesible desde cualquier contexto
final class KeychainService: Sendable {
    static let shared = KeychainService()
    
    private let serviceName = Constants.Keychain.serviceName
    private let accessGroup: String? = nil // Cambiar si necesitas compartir entre apps
    
    private init() {}
    
    // MARK: - OTP Secrets
    
    /// Guarda un secreto OTP en el Keychain
    func saveSecret(_ secret: String, for accountId: UUID) throws {
        let key = secretKey(for: accountId)
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Primero intentar eliminar si existe
        try? deleteSecret(for: accountId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Recupera un secreto OTP del Keychain
    func getSecret(for accountId: UUID) throws -> String {
        let key = secretKey(for: accountId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }
        
        guard let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return secret
    }
    
    /// Elimina un secreto OTP del Keychain
    func deleteSecret(for accountId: UUID) throws {
        let key = secretKey(for: accountId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Verifica si existe un secreto
    func secretExists(for accountId: UUID) -> Bool {
        do {
            _ = try getSecret(for: accountId)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - PIN Storage
    
    private let pinKey = Constants.Keychain.pinKey
    
    /// Guarda el hash del PIN
    func savePINHash(_ hash: String) throws {
        guard let data = hash.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        try? deletePINHash()
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Recupera el hash del PIN
    func getPINHash() throws -> String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }
        
        guard let data = result as? Data,
              let hash = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return hash
    }
    
    /// Elimina el hash del PIN
    func deletePINHash() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: pinKey
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Group PIN Storage
    
    private func groupPINKey(for groupId: UUID) -> String {
        Constants.Keychain.groupPINKey(for: groupId)
    }
    
    /// Guarda el hash del PIN de un grupo
    func saveGroupPINHash(_ hash: String, for groupId: UUID) throws {
        let key = groupPINKey(for: groupId)
        
        guard let data = hash.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        try? deleteGroupPINHash(for: groupId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Recupera el hash del PIN de un grupo
    func getGroupPINHash(for groupId: UUID) throws -> String {
        let key = groupPINKey(for: groupId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.itemNotFound
        }
        
        guard let data = result as? Data,
              let hash = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return hash
    }
    
    /// Elimina el hash del PIN de un grupo
    func deleteGroupPINHash(for groupId: UUID) throws {
        let key = groupPINKey(for: groupId)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Helpers
    
    private func secretKey(for accountId: UUID) -> String {
        Constants.Keychain.secretKey(for: accountId)
    }
}

// MARK: - Errors
enum KeychainError: LocalizedError, Sendable {
    case encodingFailed
    case decodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Error al codificar los datos."
        case .decodingFailed:
            return "Error al decodificar los datos."
        case .saveFailed(let status):
            return "Error al guardar en Keychain: \(status)"
        case .deleteFailed(let status):
            return "Error al eliminar de Keychain: \(status)"
        case .itemNotFound:
            return "Elemento no encontrado en Keychain."
        }
    }
}

