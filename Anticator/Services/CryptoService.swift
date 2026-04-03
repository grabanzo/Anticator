//
//  CryptoService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import CryptoKit
import CommonCrypto

/// Servicio de criptografía para cifrado de backups y hashing de PIN
/// Thread-safe y accesible desde cualquier contexto
final class CryptoService: Sendable {
    static let shared = CryptoService()
    static let pbkdf2Iterations = Constants.Crypto.pbkdf2Iterations
    
    private init() {}
    
    // MARK: - Backup Encryption/Decryption
    
    /// Cifra los datos del backup con una contraseña
    func encryptBackup(payload: BackupPayload, password: String) throws -> BackupFile {
        // Generar salt e IV aleatorios
        let salt = generateRandomBytes(count: Constants.Crypto.saltSize)
        let iv = generateRandomBytes(count: Constants.Crypto.gcmNonceSize)
        
        // Derivar clave de la contraseña
        let key = try deriveKey(from: password, salt: salt)
        
        // Codificar payload a JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        
        // Cifrar con AES-GCM
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.seal(payloadData, using: key, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        // El combined incluye: nonce (12) + ciphertext + tag (16)
        // Pero como ya tenemos el nonce separado, extraemos solo ciphertext + tag
        let ciphertext = combined.dropFirst(12) // Quitar nonce
        let ciphertextWithoutTag = ciphertext.dropLast(16)
        let tag = combined.suffix(16)
        
        // Crear header
        let header = BackupHeader.create(salt: salt, iv: iv)
        
        return BackupFile(
            header: header,
            encryptedData: Data(ciphertextWithoutTag).base64EncodedString(),
            authTag: Data(tag).base64EncodedString()
        )
    }
    
    /// Descifra un archivo de backup con la contraseña
    func decryptBackup(file: BackupFile, password: String) throws -> BackupPayload {
        // Extraer salt e IV del header
        guard let salt = Data(base64Encoded: file.header.encryption.salt),
              let iv = Data(base64Encoded: file.header.encryption.iv),
              let encryptedData = Data(base64Encoded: file.encryptedData),
              let tag = Data(base64Encoded: file.authTag) else {
            throw CryptoError.invalidBackupFormat
        }
        
        // Derivar clave
        let key = try deriveKey(from: password, salt: salt)
        
        // Reconstruir sealed box: nonce + ciphertext + tag
        let combined = iv + encryptedData + tag
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        
        // Descifrar
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        // Decodificar JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: decryptedData)
    }
    
    // MARK: - Key Derivation
    
    /// Deriva una clave simétrica de una contraseña usando PBKDF2
    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }
        
        // Usar CommonCrypto para PBKDF2 ya que CryptoKit no lo tiene directamente
        var derivedKey = [UInt8](repeating: 0, count: Constants.Crypto.aesKeySize)
        
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(Self.pbkdf2Iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Constants.Crypto.aesKeySize
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }
        
        return SymmetricKey(data: Data(derivedKey))
    }
    
    // MARK: - PIN Hashing
    
    /// Crea un hash del PIN para almacenamiento seguro
    func hashPIN(_ pin: String) -> String {
        let salt = "\(Constants.App.name)_pin_salt_v1" // Salt fijo para PIN local
        let data = (pin + salt).data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Verifica si un PIN coincide con el hash almacenado
    func verifyPIN(_ pin: String, against storedHash: String) -> Bool {
        return hashPIN(pin) == storedHash
    }
    
    // MARK: - Group PIN Encryption (for backup)
    
    /// Cifra cuentas de un grupo con su PIN
    func encryptAccountsWithPIN(
        _ accounts: [OTPAccount.Exportable],
        groupId: UUID,
        groupName: String,
        pin: String
    ) throws -> ProtectedGroupAccounts {
        // Generar salt e IV aleatorios
        let salt = generateRandomBytes(count: Constants.Crypto.saltSize)
        let iv = generateRandomBytes(count: Constants.Crypto.gcmNonceSize)
        
        // Derivar clave del PIN
        let key = try deriveKey(from: pin, salt: salt)
        
        // Codificar cuentas a JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let accountsData = try encoder.encode(accounts)
        
        // Cifrar con AES-GCM
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.seal(accountsData, using: key, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        
        // Extraer ciphertext y tag
        let ciphertext = combined.dropFirst(12).dropLast(16)
        let tag = combined.suffix(16)
        
        return ProtectedGroupAccounts(
            groupId: groupId,
            groupName: groupName,
            accountCount: accounts.count,
            salt: salt.base64EncodedString(),
            iv: iv.base64EncodedString(),
            encrypted: Data(ciphertext).base64EncodedString(),
            authTag: Data(tag).base64EncodedString()
        )
    }
    
    /// Descifra cuentas de un grupo con su PIN
    func decryptAccountsWithPIN(
        _ protected: ProtectedGroupAccounts,
        pin: String
    ) throws -> [OTPAccount.Exportable] {
        guard let salt = Data(base64Encoded: protected.salt),
              let iv = Data(base64Encoded: protected.iv),
              let encryptedData = Data(base64Encoded: protected.encrypted),
              let tag = Data(base64Encoded: protected.authTag) else {
            throw CryptoError.invalidBackupFormat
        }
        
        // Derivar clave del PIN
        let key = try deriveKey(from: pin, salt: salt)
        
        // Reconstruir sealed box
        let combined = iv + encryptedData + tag
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        
        // Descifrar
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        // Decodificar JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([OTPAccount.Exportable].self, from: decryptedData)
    }
    
    // MARK: - Helpers
    
    private func generateRandomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}

// MARK: - Errors
enum CryptoError: LocalizedError, Sendable {
    case encryptionFailed
    case decryptionFailed
    case invalidBackupFormat
    case invalidPassword
    case keyDerivationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Error al cifrar los datos."
        case .decryptionFailed:
            return "Error al descifrar. Verifica la contraseña."
        case .invalidBackupFormat:
            return "Formato de backup inválido."
        case .invalidPassword:
            return "Contraseña inválida."
        case .keyDerivationFailed:
            return "Error al derivar la clave."
        }
    }
}

