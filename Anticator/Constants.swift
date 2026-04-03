//
//  Constants.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Constantes centralizadas de la aplicación
enum Constants: Sendable {
    
    // MARK: - App Identity
    enum App {
        static let name = "Anticator"
        static let bundleIdentifier = "org.grabanzo.Anticator"
        static let githubURL = URL(string: "https://github.com/grabanzo/Anticator")!
    }
    
    // MARK: - Keychain
    enum Keychain {
        static let serviceName = "org.grabanzo.Anticator"
        static let pinKey = "user_pin_hash"
        
        static func secretKey(for accountId: UUID) -> String {
            "otp_secret_\(accountId.uuidString)"
        }
        
        static func groupPINKey(for groupId: UUID) -> String {
            "group_pin_\(groupId.uuidString)"
        }
    }
    
    // MARK: - Crypto
    enum Crypto {
        /// Iteraciones para PBKDF2 (derivación de clave)
        /// 600,000 es el mínimo recomendado por OWASP en 2023
        static let pbkdf2Iterations = 600_000
        
        /// Tamaño de la clave AES en bytes (256 bits)
        static let aesKeySize = 32
        
        /// Tamaño del salt en bytes
        static let saltSize = 32
        
        /// Tamaño del IV/nonce para GCM en bytes
        static let gcmNonceSize = 12
    }
    
    // MARK: - Backup
    enum Backup: Sendable {
        static let fileExtension = "anticator"
        static let currentVersion = "1.0"
        static let format = "Anticator-backup"
        static let algorithm = "AES-256-GCM"
        static let kdf = "PBKDF2-SHA256"
    }
    
    // MARK: - OTP Defaults
    enum OTP {
        static let defaultDigits = 6
        static let defaultPeriod = 30
        static let defaultAlgorithm = OTPAlgorithm.sha1
        static let defaultType = OTPType.totp
        
        /// Dígitos soportados
        static let supportedDigits = [6, 8]
        
        /// Periodos soportados (en segundos)
        static let supportedPeriods = [30, 60]
    }
    
    // MARK: - UI
    enum UI {
        /// Tamaño del botón FAB
        static let fabSize: CGFloat = 56
        
        /// Duración de animaciones estándar
        static let animationDuration: Double = 0.3
        
        /// Tiempo que se muestra el badge "Copiado"
        static let copiedBadgeDuration: Double = 2.0
        
        /// Longitud del PIN
        static let pinLength = 4
    }
    
    // MARK: - Default Group
    enum DefaultGroup {
        static let name = "Personal"
        static let iconName = "person.fill"
        static let colorHex = "007AFF"
    }
    
    // MARK: - Group Options
    enum GroupOptions {
        /// Colores disponibles para grupos
        static func availableColors() -> [(name: String, hex: String)] {
            [
                ("Azul", "007AFF"),
                ("Cyan", "00D9FF"),
                ("Verde", "34C759"),
                ("Amarillo", "FFCC00"),
                ("Naranja", "FF9500"),
                ("Rojo", "FF3B30"),
                ("Rosa", "FF2D55"),
                ("Morado", "AF52DE"),
                ("Índigo", "5856D6"),
                ("Gris", "8E8E93")
            ]
        }
        
        /// Iconos disponibles para grupos
        static let availableIcons: [String] = [
            "folder.fill",
            "person.fill",
            "briefcase.fill",
            "house.fill",
            "building.2.fill",
            "bitcoinsign.circle.fill",
            "gamecontroller.fill",
            "cart.fill",
            "creditcard.fill",
            "globe",
            "star.fill",
            "heart.fill",
            "lock.fill",
            "key.fill",
            "shield.fill"
        ]
    }
    
    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let selectedGroupId = "selectedGroupId"
        static let requireAuthentication = "requireAuthentication"
        static let useBiometrics = "useBiometrics"
        static let hasSetupPIN = "hasSetupPIN"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}

// MARK: - Convenience Extensions
extension Constants.App {
    /// Versión de la app desde el bundle
    static var version: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

