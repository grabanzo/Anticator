//
//  AppState.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftUI

/// Estado global de la aplicación
@Observable
@MainActor
final class AppState {
    // MARK: - UI State
    
    var isUnlocked: Bool = false
    var isObscured: Bool = false
    var showImportSheet: Bool = false
    var pendingImportURL: URL?
    var authTrigger: Int = 0  // Se incrementa para disparar autenticación
    
    // MARK: - Group Selection
    
    /// Grupo seleccionado (stored property para reactividad)
    var selectedGroupId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedGroupId?.uuidString, forKey: Constants.UserDefaultsKeys.selectedGroupId)
        }
    }
    
    /// Grupos desbloqueados (con PIN) en esta sesión
    var unlockedGroupIds: Set<UUID> = []
    
    /// PINs de grupos desbloqueados (solo en memoria, para export cifrado)
    /// Se limpian al bloquear el grupo o al ir a background
    private var groupPINs: [UUID: String] = [:]
    
    // MARK: - Persistent Settings (stored properties para reactividad con @Observable)
    
    var requireAuthentication: Bool {
        didSet {
            UserDefaults.standard.set(requireAuthentication, forKey: Constants.UserDefaultsKeys.requireAuthentication)
        }
    }
    
    var useBiometrics: Bool {
        didSet {
            UserDefaults.standard.set(useBiometrics, forKey: Constants.UserDefaultsKeys.useBiometrics)
        }
    }
    
    var hasSetupPIN: Bool {
        didSet {
            UserDefaults.standard.set(hasSetupPIN, forKey: Constants.UserDefaultsKeys.hasSetupPIN)
        }
    }
    
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
        }
    }
    
    // MARK: - Init
    
    init() {
        // Cargar valores persistidos desde UserDefaults
        if let uuidString = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedGroupId) {
            self.selectedGroupId = UUID(uuidString: uuidString)
        }
        
        self.requireAuthentication = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.requireAuthentication) as? Bool ?? false
        self.useBiometrics = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.useBiometrics) as? Bool ?? false
        self.hasSetupPIN = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasSetupPIN)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
    }
    
    // MARK: - Computed Properties
    
    /// Solo requiere autenticación si está activado Y hay al menos un método configurado
    var shouldRequireAuthentication: Bool {
        requireAuthentication && (useBiometrics || hasSetupPIN)
    }
    
    // MARK: - Group Lock Management
    
    func isGroupUnlocked(_ groupId: UUID) -> Bool {
        unlockedGroupIds.contains(groupId)
    }
    
    /// Desbloquea un grupo y guarda el PIN en memoria (para export cifrado)
    func unlockGroup(_ groupId: UUID, withPIN pin: String? = nil) {
        unlockedGroupIds.insert(groupId)
        if let pin = pin {
            groupPINs[groupId] = pin
        }
    }
    
    /// Obtiene el PIN de un grupo desbloqueado (para export)
    func getPIN(for groupId: UUID) -> String? {
        groupPINs[groupId]
    }
    
    func lockGroup(_ groupId: UUID) {
        unlockedGroupIds.remove(groupId)
        groupPINs.removeValue(forKey: groupId)
    }
    
    func lockAllGroups() {
        unlockedGroupIds.removeAll()
        groupPINs.removeAll()
    }
}

