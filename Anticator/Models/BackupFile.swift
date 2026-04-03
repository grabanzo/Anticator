//
//  BackupFile.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Archivo de backup cifrado
struct BackupFile: Codable, Sendable {
    let header: BackupHeader
    let encryptedData: String // Base64 encoded
    let authTag: String // Base64 encoded GCM tag
    
    static let fileExtension = Constants.Backup.fileExtension
    static let currentVersion = Constants.Backup.currentVersion
}

/// Cabecera del archivo de backup con metadatos
struct BackupHeader: Codable, Sendable {
    let version: String
    let format: String
    let created: Date
    let encryption: EncryptionMetadata
    
    static func create(salt: Data, iv: Data) -> BackupHeader {
        BackupHeader(
            version: Constants.Backup.currentVersion,
            format: Constants.Backup.format,
            created: Date(),
            encryption: EncryptionMetadata(
                algorithm: Constants.Backup.algorithm,
                kdf: Constants.Backup.kdf,
                iterations: Constants.Crypto.pbkdf2Iterations,
                salt: salt.base64EncodedString(),
                iv: iv.base64EncodedString()
            )
        )
    }
}

/// Metadatos de cifrado
struct EncryptionMetadata: Codable, Sendable {
    let algorithm: String
    let kdf: String
    let iterations: Int
    let salt: String // Base64 encoded
    let iv: String // Base64 encoded
}

/// Datos del backup (antes de cifrar)
struct BackupPayload: Codable, Sendable {
    let accounts: [OTPAccount.Exportable]  // Cuentas de grupos SIN PIN
    let groups: [OTPGroup.Exportable]?  // Opcional para compatibilidad con backups antiguos
    let protectedAccounts: [ProtectedGroupAccounts]?  // Cuentas cifradas con PIN del grupo
    let exportedAt: Date
    let deviceName: String
    
    init(
        accounts: [OTPAccount.Exportable],
        groups: [OTPGroup.Exportable],
        protectedAccounts: [ProtectedGroupAccounts]? = nil,
        deviceName: String
    ) {
        self.accounts = accounts
        self.groups = groups
        self.protectedAccounts = protectedAccounts
        self.exportedAt = Date()
        self.deviceName = deviceName
    }
    
    // Decodificador personalizado para compatibilidad con backups antiguos
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decode([OTPAccount.Exportable].self, forKey: .accounts)
        groups = try container.decodeIfPresent([OTPGroup.Exportable].self, forKey: .groups)
        protectedAccounts = try container.decodeIfPresent([ProtectedGroupAccounts].self, forKey: .protectedAccounts)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        deviceName = try container.decode(String.self, forKey: .deviceName)
    }
}

/// Cuentas de un grupo cifradas con el PIN del grupo
struct ProtectedGroupAccounts: Codable, Sendable {
    let groupId: UUID
    let groupName: String  // Para mostrar al usuario al importar
    let accountCount: Int  // Para mostrar al usuario
    let salt: String       // Base64 - salt para PBKDF2
    let iv: String         // Base64 - IV para AES-GCM
    let encrypted: String  // Base64 - cuentas cifradas con el PIN
    let authTag: String    // Base64 - tag de autenticación GCM
}

// MARK: - Import Result Types

/// Info de un grupo protegido pendiente de importar (para UI)
struct PendingProtectedGroup: Sendable {
    let groupId: UUID  // ID mapeado al grupo local
    let groupName: String
    let accountCount: Int
    let protectedData: ProtectedGroupAccounts  // Datos cifrados originales
}

/// Resultado de una operación de importación
struct ImportResult: Sendable {
    let added: Int
    let updated: Int
    let skipped: Int
    var groupsAdded: Int
    var protectedGroupsPending: [PendingProtectedGroup]  // Grupos que necesitan PIN
    var protectedAccountsImported: Int  // Cuentas de grupos protegidos importadas
    var protectedAccountsSkipped: Int   // Cuentas de grupos protegidos omitidas
    
    init(added: Int, updated: Int, skipped: Int, groupsAdded: Int) {
        self.added = added
        self.updated = updated
        self.skipped = skipped
        self.groupsAdded = groupsAdded
        self.protectedGroupsPending = []
        self.protectedAccountsImported = 0
        self.protectedAccountsSkipped = 0
    }
    
    var total: Int { added + updated + protectedAccountsImported }
    
    var hasProtectedGroups: Bool { !protectedGroupsPending.isEmpty }
    
    var description: String {
        var parts: [String] = []
        if groupsAdded > 0 { parts.append("\(groupsAdded) grupos") }
        if added > 0 { parts.append("\(added) cuentas añadidas") }
        if updated > 0 { parts.append("\(updated) actualizadas") }
        if protectedAccountsImported > 0 { parts.append("\(protectedAccountsImported) protegidas") }
        if skipped > 0 { parts.append("\(skipped) sin cambios") }
        if protectedAccountsSkipped > 0 { parts.append("\(protectedAccountsSkipped) omitidas") }
        return parts.isEmpty ? "Sin cambios" : parts.joined(separator: ", ")
    }
}

// MARK: - FileDocument for Export/Import

/// Documento para usar con fileExporter/fileImporter de SwiftUI
struct BackupDocument: FileDocument {
    // Nota: Se usa literal porque readableContentTypes es nonisolated
    static var readableContentTypes: [UTType] {
        [UTType(filenameExtension: "anticator") ?? .json, .json]
    }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

