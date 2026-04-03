//
//  OTPAccountTests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

@MainActor
final class OTPAccountTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInit_DefaultValues() {
        let account = OTPAccount(
            issuer: "Google",
            accountName: "test@gmail.com",
            secretKeyRef: "test-ref"
        )
        
        XCTAssertEqual(account.issuer, "Google")
        XCTAssertEqual(account.accountName, "test@gmail.com")
        XCTAssertEqual(account.secretKeyRef, "test-ref")
        XCTAssertEqual(account.type, .totp)
        XCTAssertEqual(account.algorithm, .sha1)
        XCTAssertEqual(account.digits, 6)
        XCTAssertEqual(account.period, 30)
        XCTAssertEqual(account.counter, 0)
        XCTAssertNil(account.iconName)
        XCTAssertNil(account.groupId)
        XCTAssertEqual(account.order, 0)
        XCTAssertNil(account.deletedAt)
    }
    
    func testInit_CustomValues() {
        let groupId = UUID()
        let account = OTPAccount(
            issuer: "GitHub",
            accountName: "user",
            secretKeyRef: "ref",
            type: .hotp,
            algorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 5,
            iconName: "github",
            groupId: groupId,
            order: 10
        )
        
        XCTAssertEqual(account.type, .hotp)
        XCTAssertEqual(account.algorithm, .sha256)
        XCTAssertEqual(account.digits, 8)
        XCTAssertEqual(account.period, 60)
        XCTAssertEqual(account.counter, 5)
        XCTAssertEqual(account.iconName, "github")
        XCTAssertEqual(account.groupId, groupId)
        XCTAssertEqual(account.order, 10)
    }
    
    // MARK: - Display Name Tests
    
    func testDisplayName_WithIssuerAndAccount() {
        let account = OTPAccount(
            issuer: "Google",
            accountName: "test@gmail.com",
            secretKeyRef: "ref"
        )
        
        XCTAssertEqual(account.displayName, "Google (test@gmail.com)")
    }
    
    func testDisplayName_EmptyIssuer() {
        let account = OTPAccount(
            issuer: "",
            accountName: "test@example.com",
            secretKeyRef: "ref"
        )
        
        XCTAssertEqual(account.displayName, "test@example.com")
    }
    
    func testDisplayName_BothEmpty() {
        let account = OTPAccount(
            issuer: "",
            accountName: "",
            secretKeyRef: "ref"
        )
        
        XCTAssertEqual(account.displayName, "")
    }
    
    // MARK: - Deletion Tests
    
    func testIsDeleted_NotDeleted() {
        let account = OTPAccount(
            issuer: "Test",
            accountName: "test",
            secretKeyRef: "ref"
        )
        
        XCTAssertFalse(account.isDeleted)
    }
    
    func testIsDeleted_SoftDeleted() {
        let account = OTPAccount(
            issuer: "Test",
            accountName: "test",
            secretKeyRef: "ref",
            deletedAt: Date()
        )
        
        XCTAssertTrue(account.isDeleted)
    }
    
    // MARK: - Exportable Tests
    
    func testToExportable() {
        let groupId = UUID()
        let account = OTPAccount(
            issuer: "Google",
            accountName: "test@gmail.com",
            secretKeyRef: "ref-id",
            type: .totp,
            algorithm: .sha256,
            digits: 8,
            period: 60,
            counter: 0,
            iconName: "google",
            groupId: groupId,
            order: 5
        )
        
        let secret = "JBSWY3DPEHPK3PXP"
        let exportable = account.toExportable(secret: secret)
        
        XCTAssertEqual(exportable.id, account.id)
        XCTAssertEqual(exportable.issuer, "Google")
        XCTAssertEqual(exportable.accountName, "test@gmail.com")
        XCTAssertEqual(exportable.secret, secret)
        XCTAssertEqual(exportable.type, .totp)
        XCTAssertEqual(exportable.algorithm, .sha256)
        XCTAssertEqual(exportable.digits, 8)
        XCTAssertEqual(exportable.period, 60)
        XCTAssertEqual(exportable.iconName, "google")
        XCTAssertEqual(exportable.groupId, groupId)
        XCTAssertEqual(exportable.order, 5)
    }
    
    func testExportable_Codable() throws {
        let exportable = OTPAccount.Exportable(
            id: UUID(),
            issuer: "GitHub",
            accountName: "user",
            secret: "JBSWY3DPEHPK3PXP",
            type: .totp,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            counter: 0,
            iconName: "github",
            order: 0,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil,
            groupId: nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportable)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OTPAccount.Exportable.self, from: data)
        
        XCTAssertEqual(decoded.issuer, exportable.issuer)
        XCTAssertEqual(decoded.accountName, exportable.accountName)
        XCTAssertEqual(decoded.secret, exportable.secret)
        XCTAssertEqual(decoded.type, exportable.type)
        XCTAssertEqual(decoded.algorithm, exportable.algorithm)
    }
    
    func testExportable_BackwardsCompatibility_NoGroupId() throws {
        // Simular JSON de backup antiguo sin groupId
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "issuer": "Test",
            "accountName": "test@example.com",
            "secret": "JBSWY3DPEHPK3PXP",
            "type": "totp",
            "algorithm": "sha1",
            "digits": 6,
            "period": 30,
            "counter": 0,
            "order": 0,
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportable = try decoder.decode(OTPAccount.Exportable.self, from: json.data(using: .utf8)!)
        
        XCTAssertNil(exportable.groupId)
        XCTAssertNil(exportable.iconName)
        XCTAssertEqual(exportable.issuer, "Test")
    }
}

// MARK: - OTPType Tests

@MainActor
final class OTPTypeTests: XCTestCase {
    
    func testOTPType_Codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let totpData = try encoder.encode(OTPType.totp)
        let hotpData = try encoder.encode(OTPType.hotp)
        
        let decodedTOTP = try decoder.decode(OTPType.self, from: totpData)
        let decodedHOTP = try decoder.decode(OTPType.self, from: hotpData)
        
        XCTAssertEqual(decodedTOTP, .totp)
        XCTAssertEqual(decodedHOTP, .hotp)
    }
}

// MARK: - OTPAlgorithm Tests

@MainActor
final class OTPAlgorithmTests: XCTestCase {
    
    func testOTPAlgorithm_Codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let algorithms: [OTPAlgorithm] = [.sha1, .sha256, .sha512]
        
        for algorithm in algorithms {
            let data = try encoder.encode(algorithm)
            let decoded = try decoder.decode(OTPAlgorithm.self, from: data)
            XCTAssertEqual(decoded, algorithm)
        }
    }
    
    func testOTPAlgorithm_AllCases() {
        XCTAssertEqual(OTPAlgorithm.allCases.count, 3)
        XCTAssertTrue(OTPAlgorithm.allCases.contains(.sha1))
        XCTAssertTrue(OTPAlgorithm.allCases.contains(.sha256))
        XCTAssertTrue(OTPAlgorithm.allCases.contains(.sha512))
    }
}

