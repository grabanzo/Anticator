//
//  ExportImportService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData

/// Servicio para exportar e importar backups de cuentas OTP
@MainActor
final class ExportImportService {
    static let shared = ExportImportService()
    
    private let cryptoService = CryptoService.shared
    private let keychainService = KeychainService.shared
    private let otpAccountService = OTPAccountService.shared
    
    private init() {}
    
    // MARK: - Export
    
    /// Exporta todas las cuentas OTP y grupos a Data cifrada
    /// - Parameters:
    ///   - accounts: Cuentas a exportar
    ///   - groups: Grupos a exportar
    ///   - password: Contraseña para cifrar el backup
    ///   - groupPINs: Diccionario [groupId: PIN] para grupos protegidos
    ///   - deviceName: Nombre del dispositivo
    func exportAccountsToData(
        _ accounts: [OTPAccount],
        groups: [OTPGroup],
        password: String,
        groupPINs: [UUID: String] = [:],
        deviceName: String
    ) throws -> Data {
        // Identificar grupos con PIN
        let groupsWithPIN = Set(groups.filter { $0.requiresPIN }.map { $0.id })
        let groupsById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        
        // Separar cuentas en grupos sin PIN y grupos con PIN
        var unprotectedAccounts: [OTPAccount.Exportable] = []
        var accountsByProtectedGroup: [UUID: [OTPAccount.Exportable]] = [:]
        
        for account in accounts where !account.isDeleted {
            do {
                let secret = try keychainService.getSecret(for: account.id)
                let exportable = account.toExportable(secret: secret)
                
                if let groupId = account.groupId, groupsWithPIN.contains(groupId) {
                    // Cuenta de grupo con PIN
                    accountsByProtectedGroup[groupId, default: []].append(exportable)
                } else {
                    // Cuenta de grupo sin PIN
                    unprotectedAccounts.append(exportable)
                }
            } catch {
                continue
            }
        }
        
        guard !unprotectedAccounts.isEmpty || !accountsByProtectedGroup.isEmpty else {
            throw ExportError.noAccountsToExport
        }
        
        // Cifrar cuentas de grupos protegidos con su PIN
        var protectedAccounts: [ProtectedGroupAccounts] = []
        
        for (groupId, accounts) in accountsByProtectedGroup {
            guard let pin = groupPINs[groupId],
                  let group = groupsById[groupId] else {
                // Si no tenemos el PIN, no podemos exportar estas cuentas
                // Esto no debería pasar si la validación en SettingsView funciona
                continue
            }
            
            let protected = try cryptoService.encryptAccountsWithPIN(
                accounts,
                groupId: groupId,
                groupName: group.name,
                pin: pin
            )
            protectedAccounts.append(protected)
        }
        
        // Convertir grupos a formato exportable
        let exportableGroups = groups.map { $0.toExportable() }
        
        // Crear payload
        let payload = BackupPayload(
            accounts: unprotectedAccounts,
            groups: exportableGroups,
            protectedAccounts: protectedAccounts.isEmpty ? nil : protectedAccounts,
            deviceName: deviceName
        )
        
        // Cifrar
        let backupFile = try cryptoService.encryptBackup(payload: payload, password: password)
        
        // Codificar a JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backupFile)
    }
    
    /// Exporta todas las cuentas OTP a un archivo cifrado (legacy - para compartir)
    func exportAccounts(
        _ accounts: [OTPAccount],
        groups: [OTPGroup],
        password: String,
        deviceName: String
    ) throws -> URL {
        let data = try exportAccountsToData(accounts, groups: groups, password: password, deviceName: deviceName)
        
        // Guardar en archivo temporal
        let fileName = "\(Constants.App.name)_backup_\(formattedDate()).\(Constants.Backup.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Import
    
    /// Importa cuentas y grupos desde un archivo de backup
    func importAccounts(
        from url: URL,
        password: String,
        existingAccounts: [OTPAccount],
        existingGroups: [OTPGroup],
        context: ModelContext,
        defaultGroupId: UUID? = nil
    ) throws -> ImportResult {
        // Leer archivo
        let data: Data
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            data = try Data(contentsOf: url)
        } else {
            data = try Data(contentsOf: url)
        }
        
        // Decodificar
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupFile = try decoder.decode(BackupFile.self, from: data)
        
        // Verificar versión
        guard backupFile.header.version == BackupFile.currentVersion else {
            throw ImportError.unsupportedVersion(backupFile.header.version)
        }
        
        // Descifrar
        let payload: BackupPayload
        do {
            payload = try cryptoService.decryptBackup(file: backupFile, password: password)
        } catch {
            throw ImportError.wrongPassword
        }
        
        // Primero importar grupos si vienen en el backup
        // Devuelve mapeo de ID importado -> ID a usar (puede ser existente si hay match por nombre)
        var groupsAdded = 0
        var groupIdMapping: [UUID: UUID] = [:]
        
        if let importedGroups = payload.groups {
            let mergeResult = mergeGroups(
                imported: importedGroups,
                existing: existingGroups,
                context: context
            )
            groupsAdded = mergeResult.added
            groupIdMapping = mergeResult.mapping
        }
        
        // Usar el defaultGroupId pasado, o buscar uno si no se pasó
        let groupIdToUse = defaultGroupId ?? getDefaultGroupId(from: existingGroups)
        
        // Merge con cuentas existentes, usando el mapeo de grupos
        var result = try mergeAccounts(
            imported: payload.accounts,
            existing: existingAccounts,
            context: context,
            defaultGroupId: groupIdToUse,
            groupIdMapping: groupIdMapping
        )
        
        result.groupsAdded = groupsAdded
        
        // Extraer grupos protegidos pendientes de importar
        if let protectedAccounts = payload.protectedAccounts {
            for protectedGroup in protectedAccounts {
                // Mapear al ID real del grupo (puede haber cambiado si ya existía)
                let actualGroupId = groupIdMapping[protectedGroup.groupId] ?? protectedGroup.groupId
                
                result.protectedGroupsPending.append(
                    PendingProtectedGroup(
                        groupId: actualGroupId,
                        groupName: protectedGroup.groupName,
                        accountCount: protectedGroup.accountCount,
                        protectedData: protectedGroup
                    )
                )
            }
        }
        
        return result
    }
    
    /// Importa cuentas protegidas de un grupo después de verificar el PIN
    func importProtectedAccounts(
        _ pendingGroup: PendingProtectedGroup,
        pin: String,
        targetGroupId: UUID,  // ID del grupo local donde importar
        existingAccounts: [OTPAccount],
        context: ModelContext
    ) throws -> (imported: Int, skipped: Int) {
        // Descifrar las cuentas con el PIN
        let accounts: [OTPAccount.Exportable]
        do {
            accounts = try cryptoService.decryptAccountsWithPIN(pendingGroup.protectedData, pin: pin)
        } catch {
            throw ImportError.wrongPIN
        }
        
        var imported = 0
        var skipped = 0
        
        let existingById = Dictionary(uniqueKeysWithValues: existingAccounts.map { ($0.id, $0) })
        
        for account in accounts {
            // Verificar si ya existe
            if existingById[account.id] != nil {
                skipped += 1
                continue
            }
            
            // Crear nueva cuenta con el grupo mapeado (reutiliza la función existente)
            let newAccount = createAccount(from: account, groupId: targetGroupId)
            
            // Insertar con secreto usando el servicio
            try otpAccountService.insertAccount(newAccount, secret: account.secret, in: context)
            
            imported += 1
        }
        
        try context.save()
        
        return (imported, skipped)
    }
    
    /// Obtiene el ID del primer grupo (por orden) para asignar a cuentas importadas sin grupo
    private func getDefaultGroupId(from groups: [OTPGroup]) -> UUID? {
        groups.sorted { $0.order < $1.order }.first?.id
    }
    
    // MARK: - Merge Logic
    
    private struct GroupMergeResult {
        let added: Int
        let mapping: [UUID: UUID]  // importedGroupId -> actualGroupId
    }
    
    private func mergeGroups(
        imported: [OTPGroup.Exportable],
        existing: [OTPGroup],
        context: ModelContext
    ) -> GroupMergeResult {
        var added = 0
        var mapping: [UUID: UUID] = [:]
        
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let existingByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name.lowercased(), $0) })
        
        for importedGroup in imported {
            // Primero verificar si existe por ID
            if let existingGroup = existingById[importedGroup.id] {
                // Mismo ID - mapear directamente
                mapping[importedGroup.id] = existingGroup.id
            }
            // Si no existe por ID, verificar por nombre
            else if let existingGroup = existingByName[importedGroup.name.lowercased()] {
                // Existe un grupo con el mismo nombre - reusar ese
                mapping[importedGroup.id] = existingGroup.id
            }
            else {
                // Grupo nuevo - añadir (operación simple, modelContext directo)
                let newGroup = OTPGroup(
                    id: importedGroup.id,
                    name: importedGroup.name,
                    iconName: importedGroup.iconName,
                    colorHex: importedGroup.colorHex,
                    order: importedGroup.order,
                    requiresPIN: false  // No importamos el PIN por seguridad
                )
                context.insert(newGroup)
                mapping[importedGroup.id] = importedGroup.id
                added += 1
            }
        }
        
        return GroupMergeResult(added: added, mapping: mapping)
    }
    
    private func mergeAccounts(
        imported: [OTPAccount.Exportable],
        existing: [OTPAccount],
        context: ModelContext,
        defaultGroupId: UUID?,
        groupIdMapping: [UUID: UUID] = [:]
    ) throws -> ImportResult {
        var added = 0
        var updated = 0
        var skipped = 0
        
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        
        for importedAccount in imported {
            // Si está marcado como eliminado, propagar la eliminación
            if importedAccount.deletedAt != nil {
                if let existingAccount = existingById[importedAccount.id] {
                    existingAccount.deletedAt = importedAccount.deletedAt
                    existingAccount.updatedAt = importedAccount.updatedAt
                    updated += 1
                }
                continue
            }
            
            if let existingAccount = existingById[importedAccount.id] {
                // La cuenta existe - comparar timestamps
                if importedAccount.updatedAt > existingAccount.updatedAt {
                    // La importada es más reciente - actualizar
                    updateAccount(existingAccount, from: importedAccount)
                    
                    // Actualizar secreto en Keychain - usar Service
                    try otpAccountService.updateSecret(importedAccount.secret, for: existingAccount)
                    
                    updated += 1
                } else {
                    // La local es más reciente o igual - mantener
                    skipped += 1
                }
            } else {
                // Cuenta nueva - añadir
                // Mapear el groupId usando el mapping (redirige a grupos existentes si hay match por nombre)
                var groupIdToAssign: UUID? = defaultGroupId
                if let importedGroupId = importedAccount.groupId {
                    // Si hay mapeo, usar el ID mapeado; si no, usar el default
                    groupIdToAssign = groupIdMapping[importedGroupId] ?? defaultGroupId
                }
                
                let newAccount = createAccount(from: importedAccount, groupId: groupIdToAssign)
                // Insert con secreto - usar Service
                try otpAccountService.insertAccount(newAccount, secret: importedAccount.secret, in: context)
                
                added += 1
            }
        }
        
        try context.save()
        
        return ImportResult(added: added, updated: updated, skipped: skipped, groupsAdded: 0)
    }
    
    private func updateAccount(_ account: OTPAccount, from imported: OTPAccount.Exportable) {
        account.issuer = imported.issuer
        account.accountName = imported.accountName
        account.type = imported.type
        account.algorithm = imported.algorithm
        account.digits = imported.digits
        account.period = imported.period
        account.counter = imported.counter
        account.iconName = imported.iconName
        account.order = imported.order
        account.updatedAt = imported.updatedAt
        account.deletedAt = imported.deletedAt
        // Preservar groupId si viene en el import
        if let groupId = imported.groupId {
            account.groupId = groupId
        }
    }
    
    private func createAccount(from imported: OTPAccount.Exportable, groupId: UUID?) -> OTPAccount {
        OTPAccount(
            id: imported.id,
            issuer: imported.issuer,
            accountName: imported.accountName,
            secretKeyRef: imported.id.uuidString, // Referencia al Keychain
            type: imported.type,
            algorithm: imported.algorithm,
            digits: imported.digits,
            period: imported.period,
            counter: imported.counter,
            iconName: imported.iconName,
            groupId: groupId,
            order: imported.order,
            createdAt: imported.createdAt,
            updatedAt: imported.updatedAt,
            deletedAt: imported.deletedAt
        )
    }
    
    // MARK: - Helpers
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Errors
enum ExportError: LocalizedError, Sendable {
    case noAccountsToExport
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noAccountsToExport:
            return "No hay cuentas para exportar."
        case .encodingFailed:
            return "Error al codificar los datos."
        }
    }
}

enum ImportError: LocalizedError, Sendable {
    case invalidFile
    case unsupportedVersion(String)
    case wrongPassword
    case wrongPIN
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "El archivo no es válido."
        case .wrongPIN:
            return "PIN incorrecto para el grupo."
        case .unsupportedVersion(let version):
            return "Versión de backup no soportada: \(version)"
        case .wrongPassword:
            return "Contraseña incorrecta."
        case .decodingFailed:
            return "Error al decodificar el archivo."
        }
    }
}
