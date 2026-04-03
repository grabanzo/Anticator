//
//  AnticatorTests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

/// Tests de integración general de la aplicación
@MainActor
final class AnticatorTests: XCTestCase {
    
    // MARK: - Constants Tests
    
    func testConstants_AppName() {
        XCTAssertEqual(Constants.App.name, "Anticator")
    }
    
    func testConstants_BackupExtension() {
        XCTAssertEqual(Constants.Backup.fileExtension, "anticator")
    }
    
    func testConstants_CryptoValues() {
        XCTAssertEqual(Constants.Crypto.aesKeySize, 32) // 256 bits
        XCTAssertEqual(Constants.Crypto.gcmNonceSize, 12) // 96 bits
        XCTAssertEqual(Constants.Crypto.saltSize, 32) // 256 bits
        XCTAssertGreaterThan(Constants.Crypto.pbkdf2Iterations, 100000)
    }
    
    // MARK: - Integration Tests
    
    func testOTPGeneration_FullFlow() throws {
        // Test completo de generación OTP
        let secret = "JBSWY3DPEHPK3PXP"
        let service = OTPGeneratorService.shared
        
        // Verificar que podemos generar un código
        let code = try service.generateTOTP(secret: secret)
        
        // Verificar formato
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy { $0.isNumber })
        
        // Verificar que el progreso funciona
        let progress = service.progress()
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
        
        // Verificar segundos restantes
        let remaining = service.secondsRemaining()
        XCTAssertGreaterThan(remaining, 0)
        XCTAssertLessThanOrEqual(remaining, 30)
    }
    
    func testBackupEncryption_FullFlow() throws {
        let crypto = CryptoService.shared
        
        // Crear datos de prueba
        let accounts = [
            OTPAccount.Exportable(
                id: UUID(),
                issuer: "Test Service",
                accountName: "user@test.com",
                secret: "JBSWY3DPEHPK3PXP",
                type: .totp,
                algorithm: .sha1,
                digits: 6,
                period: 30,
                counter: 0,
                iconName: nil,
                order: 0,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil,
                groupId: nil
            )
        ]
        
        let payload = BackupPayload(
            accounts: accounts,
            groups: [],
            deviceName: "Test Device"
        )
        
        // Cifrar con contraseña
        let password = "TestPassword123!"
        let encrypted = try crypto.encryptBackup(payload: payload, password: password)
        
        // Verificar estructura del archivo cifrado
        XCTAssertFalse(encrypted.encryptedData.isEmpty)
        XCTAssertFalse(encrypted.authTag.isEmpty)
        XCTAssertEqual(encrypted.header.version, "1.0")
        XCTAssertEqual(encrypted.header.encryption.algorithm, "AES-256-GCM")
        
        // Descifrar y verificar
        let decrypted = try crypto.decryptBackup(file: encrypted, password: password)
        XCTAssertEqual(decrypted.accounts.count, 1)
        XCTAssertEqual(decrypted.accounts.first?.issuer, "Test Service")
        XCTAssertEqual(decrypted.accounts.first?.secret, "JBSWY3DPEHPK3PXP")
    }
    
    func testBase32_ConsistentWithOTPGeneration() throws {
        // Verificar que la codificación Base32 es consistente
        let originalSecret = "Hello!"
        let data = originalSecret.data(using: .utf8)!
        
        // Codificar a Base32
        let encoded = Base32.encode(data)
        
        // El secreto codificado debe funcionar en OTP
        let service = OTPGeneratorService.shared
        let code = try service.generateTOTP(secret: encoded)
        
        XCTAssertEqual(code.count, 6)
    }
}
