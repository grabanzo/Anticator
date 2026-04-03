//
//  CryptoServiceTests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

@MainActor
final class CryptoServiceTests: XCTestCase {
    
    private let service = CryptoService.shared
    
    // MARK: - PIN Hashing Tests
    
    func testHashPIN_Deterministic() {
        let pin = "123456"
        
        let hash1 = service.hashPIN(pin)
        let hash2 = service.hashPIN(pin)
        
        XCTAssertEqual(hash1, hash2, "El mismo PIN debe producir el mismo hash")
    }
    
    func testHashPIN_DifferentPINsProduceDifferentHashes() {
        let hash1 = service.hashPIN("123456")
        let hash2 = service.hashPIN("654321")
        let hash3 = service.hashPIN("000000")
        
        XCTAssertNotEqual(hash1, hash2)
        XCTAssertNotEqual(hash2, hash3)
        XCTAssertNotEqual(hash1, hash3)
    }
    
    func testHashPIN_Format() {
        let hash = service.hashPIN("123456")
        
        // SHA256 produce 64 caracteres hexadecimales
        XCTAssertEqual(hash.count, 64)
        
        // Solo caracteres hexadecimales
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(hash.unicodeScalars.allSatisfy { hexCharacters.contains($0) })
    }
    
    func testHashPIN_NotPlaintext() {
        let pin = "123456"
        let hash = service.hashPIN(pin)
        
        // El hash no debe contener el PIN original
        XCTAssertFalse(hash.contains(pin))
    }
    
    // MARK: - PIN Verification Tests
    
    func testVerifyPIN_CorrectPIN() {
        let pin = "123456"
        let hash = service.hashPIN(pin)
        
        XCTAssertTrue(service.verifyPIN(pin, against: hash))
    }
    
    func testVerifyPIN_WrongPIN() {
        let correctPin = "123456"
        let wrongPin = "654321"
        let hash = service.hashPIN(correctPin)
        
        XCTAssertFalse(service.verifyPIN(wrongPin, against: hash))
    }
    
    func testVerifyPIN_EmptyPIN() {
        let pin = ""
        let hash = service.hashPIN(pin)
        
        XCTAssertTrue(service.verifyPIN("", against: hash))
        XCTAssertFalse(service.verifyPIN("123456", against: hash))
    }
    
    func testVerifyPIN_SimilarPINs() {
        let hash = service.hashPIN("123456")
        
        // PINs similares no deben verificar
        XCTAssertFalse(service.verifyPIN("123457", against: hash))
        XCTAssertFalse(service.verifyPIN("023456", against: hash))
        XCTAssertFalse(service.verifyPIN("12345", against: hash))
        XCTAssertFalse(service.verifyPIN("1234567", against: hash))
    }
    
    // MARK: - Backup Encryption/Decryption Tests
    
    func testBackupEncryptDecrypt_RoundTrip() throws {
        let accounts = [
            OTPAccount.Exportable(
                id: UUID(),
                issuer: "Google",
                accountName: "test@gmail.com",
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
        
        let password = "SecurePassword123!"
        
        // Cifrar
        let encryptedFile = try service.encryptBackup(payload: payload, password: password)
        
        // Descifrar
        let decryptedPayload = try service.decryptBackup(file: encryptedFile, password: password)
        
        // Verificar
        XCTAssertEqual(decryptedPayload.accounts.count, 1)
        XCTAssertEqual(decryptedPayload.accounts.first?.issuer, "Google")
        XCTAssertEqual(decryptedPayload.accounts.first?.accountName, "test@gmail.com")
        XCTAssertEqual(decryptedPayload.accounts.first?.secret, "JBSWY3DPEHPK3PXP")
    }
    
    func testBackupEncrypt_DifferentEachTime() throws {
        let payload = BackupPayload(
            accounts: [],
            groups: [],
            deviceName: "Test"
        )
        
        let password = "password"
        
        let encrypted1 = try service.encryptBackup(payload: payload, password: password)
        let encrypted2 = try service.encryptBackup(payload: payload, password: password)
        
        // Cada cifrado debe ser diferente (salt/IV aleatorios)
        XCTAssertNotEqual(encrypted1.header.encryption.salt, encrypted2.header.encryption.salt)
        XCTAssertNotEqual(encrypted1.header.encryption.iv, encrypted2.header.encryption.iv)
        XCTAssertNotEqual(encrypted1.encryptedData, encrypted2.encryptedData)
    }
    
    func testBackupDecrypt_WrongPassword() throws {
        let payload = BackupPayload(
            accounts: [],
            groups: [],
            deviceName: "Test"
        )
        
        let encrypted = try service.encryptBackup(payload: payload, password: "correct")
        
        XCTAssertThrowsError(try service.decryptBackup(file: encrypted, password: "wrong"))
    }
    
    func testBackupDecrypt_MultipleAccounts() throws {
        let accounts = (0..<5).map { i in
            OTPAccount.Exportable(
                id: UUID(),
                issuer: "Service\(i)",
                accountName: "user\(i)@example.com",
                secret: "JBSWY3DPEHPK3PXP",
                type: .totp,
                algorithm: .sha1,
                digits: 6,
                period: 30,
                counter: 0,
                iconName: nil,
                order: i,
                createdAt: Date(),
                updatedAt: Date(),
                deletedAt: nil,
                groupId: nil
            )
        }
        
        let groupId = UUID()
        let groups = [
            OTPGroup.Exportable(
                id: groupId,
                name: "Test Group",
                iconName: "folder",
                colorHex: "#FF0000",
                order: 0,
                requiresPIN: false,
                createdAt: Date()
            )
        ]
        
        let payload = BackupPayload(
            accounts: accounts,
            groups: groups,
            deviceName: "Test Device"
        )
        
        let password = "TestPassword"
        
        let encrypted = try service.encryptBackup(payload: payload, password: password)
        let decrypted = try service.decryptBackup(file: encrypted, password: password)
        
        XCTAssertEqual(decrypted.accounts.count, 5)
        XCTAssertEqual(decrypted.groups?.count, 1)
        XCTAssertEqual(decrypted.deviceName, "Test Device")
    }
}

