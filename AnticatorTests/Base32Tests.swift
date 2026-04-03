//
//  Base32Tests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

@MainActor
final class Base32Tests: XCTestCase {
    
    // MARK: - Round Trip Tests (most important)
    
    func testRoundTrip_SimpleText() throws {
        let original = "Hello"
        let data = original.data(using: .utf8)!
        
        let encoded = Base32.encode(data)
        let decoded = try Base32.decode(encoded)
        let result = String(data: decoded, encoding: .utf8)!
        
        XCTAssertEqual(result, original)
    }
    
    func testRoundTrip_LongerText() throws {
        let original = "Hello, World! 123"
        let data = original.data(using: .utf8)!
        
        let encoded = Base32.encode(data)
        let decoded = try Base32.decode(encoded)
        let result = String(data: decoded, encoding: .utf8)!
        
        XCTAssertEqual(result, original)
    }
    
    func testRoundTrip_BinaryData() throws {
        let data = Data([0x00, 0xFF, 0x80, 0x7F, 0xAB, 0xCD, 0xEF])
        
        let encoded = Base32.encode(data)
        let decoded = try Base32.decode(encoded)
        
        XCTAssertEqual(decoded, data)
    }
    
    func testRoundTrip_RandomData() throws {
        for _ in 0..<10 {
            var randomBytes = [UInt8](repeating: 0, count: Int.random(in: 1...100))
            _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            let original = Data(randomBytes)
            
            let encoded = Base32.encode(original)
            let decoded = try Base32.decode(encoded)
            
            XCTAssertEqual(decoded, original, "Round trip failed for \(randomBytes.count) bytes")
        }
    }
    
    func testRoundTrip_OTPSecret() throws {
        // Secreto típico de OTP
        let secret = "JBSWY3DPEHPK3PXP"
        
        // Decodificar y volver a codificar
        let decoded = try Base32.decode(secret)
        let reencoded = Base32.encode(decoded)
        
        // Volver a decodificar para verificar
        let redecoded = try Base32.decode(reencoded)
        
        XCTAssertEqual(decoded, redecoded)
    }
    
    // MARK: - Decode Tests
    
    func testDecode_CommonOTPSecrets() throws {
        // Secretos típicos de OTP que deben decodificarse sin error
        let secrets = [
            "JBSWY3DPEHPK3PXP",
            "GEZDGNBVGY3TQOJQ",
            "MFRGGZDFMY",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        ]
        
        for secret in secrets {
            XCTAssertNoThrow(try Base32.decode(secret), "Should decode: \(secret)")
        }
    }
    
    func testDecode_CaseInsensitive() throws {
        let upper = "JBSWY3DPEHPK3PXP"
        let lower = "jbswy3dpehpk3pxp"
        let mixed = "JbSwY3DpEhPk3PxP"
        
        let decodedUpper = try Base32.decode(upper)
        let decodedLower = try Base32.decode(lower)
        let decodedMixed = try Base32.decode(mixed)
        
        XCTAssertEqual(decodedUpper, decodedLower)
        XCTAssertEqual(decodedUpper, decodedMixed)
    }
    
    func testDecode_WithPadding() throws {
        // El padding debe ser ignorado
        let withPadding = "MFRGGZDFMY======"
        let withoutPadding = "MFRGGZDFMY"
        
        let decodedWith = try Base32.decode(withPadding)
        let decodedWithout = try Base32.decode(withoutPadding)
        
        XCTAssertEqual(decodedWith, decodedWithout)
    }
    
    func testDecode_WithSpaces() throws {
        // Los espacios deben ser ignorados
        let withSpaces = "JBSW Y3DP EHPK 3PXP"
        let withoutSpaces = "JBSWY3DPEHPK3PXP"
        
        let decodedWith = try Base32.decode(withSpaces)
        let decodedWithout = try Base32.decode(withoutSpaces)
        
        XCTAssertEqual(decodedWith, decodedWithout)
    }
    
    func testDecode_WithDashes() throws {
        // Los guiones deben ser ignorados
        let withDashes = "JBSW-Y3DP-EHPK-3PXP"
        let withoutDashes = "JBSWY3DPEHPK3PXP"
        
        let decodedWith = try Base32.decode(withDashes)
        let decodedWithout = try Base32.decode(withoutDashes)
        
        XCTAssertEqual(decodedWith, decodedWithout)
    }
    
    func testDecode_EmptyString() throws {
        let decoded = try Base32.decode("")
        XCTAssertEqual(decoded.count, 0)
    }
    
    // MARK: - Encode Tests
    
    func testEncode_ProducesValidBase32() {
        let data = "Test".data(using: .utf8)!
        let encoded = Base32.encode(data)
        
        // Solo debe contener caracteres Base32 válidos
        let validChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        XCTAssertTrue(encoded.unicodeScalars.allSatisfy { validChars.contains($0) })
    }
    
    func testEncode_EmptyData() {
        let encoded = Base32.encode(Data())
        XCTAssertEqual(encoded, "")
    }
    
    func testEncode_ConsistentResults() {
        let data = "Consistent".data(using: .utf8)!
        
        let encoded1 = Base32.encode(data)
        let encoded2 = Base32.encode(data)
        
        XCTAssertEqual(encoded1, encoded2, "Encoding should be deterministic")
    }
    
    // MARK: - Validation Tests
    
    func testIsValid_ValidStrings() {
        XCTAssertTrue(Base32.isValid("MFRGGZDFMY"))
        XCTAssertTrue(Base32.isValid("mfrggzdfmy"))
        XCTAssertTrue(Base32.isValid("JBSWY3DPEHPK3PXP"))
        XCTAssertTrue(Base32.isValid("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"))
        XCTAssertTrue(Base32.isValid("")) // Vacío es válido
        XCTAssertTrue(Base32.isValid("ABC DEF")) // Con espacios
        XCTAssertTrue(Base32.isValid("ABC-DEF")) // Con guiones
        XCTAssertTrue(Base32.isValid("ABC====")) // Con padding
    }
    
    func testIsValid_InvalidStrings() {
        XCTAssertFalse(Base32.isValid("0189")) // 0, 1, 8, 9 no son Base32 válidos
        XCTAssertFalse(Base32.isValid("ABC!@#"))
        XCTAssertFalse(Base32.isValid("HELLO_WORLD"))
        XCTAssertFalse(Base32.isValid("abc.def"))
    }
    
    // MARK: - Error Tests
    
    func testDecode_InvalidCharacters() {
        XCTAssertThrowsError(try Base32.decode("INVALID!")) { error in
            XCTAssertTrue(error is Base32.Base32Error)
        }
    }
    
    func testDecode_NumbersOutOfRange() {
        // 0, 1, 8, 9 no son válidos en Base32 estándar
        XCTAssertThrowsError(try Base32.decode("ABC01890"))
    }
}
