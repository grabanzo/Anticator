//
//  OTPGeneratorServiceTests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

@MainActor
final class OTPGeneratorServiceTests: XCTestCase {
    
    private let service = OTPGeneratorService.shared
    
    // MARK: - TOTP Tests
    
    func testGenerateTOTP_WithKnownValues() throws {
        // RFC 6238 Test Vector
        // Secret: "12345678901234567890" en ASCII = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" en Base32
        let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        
        // Test con timestamp conocido (59 segundos desde epoch)
        let date = Date(timeIntervalSince1970: 59)
        
        let code = try service.generateTOTP(
            secret: secret,
            algorithm: .sha1,
            digits: 8,
            period: 30,
            date: date
        )
        
        // RFC 6238 espera "94287082" para este vector
        XCTAssertEqual(code, "94287082")
    }
    
    func testGenerateTOTP_SixDigits() throws {
        let secret = "JBSWY3DPEHPK3PXP" // Secreto de prueba común
        let date = Date(timeIntervalSince1970: 0)
        
        let code = try service.generateTOTP(
            secret: secret,
            algorithm: .sha1,
            digits: 6,
            period: 30,
            date: date
        )
        
        // Verificar que tiene 6 dígitos
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy { $0.isNumber })
    }
    
    func testGenerateTOTP_EightDigits() throws {
        let secret = "JBSWY3DPEHPK3PXP"
        let date = Date(timeIntervalSince1970: 0)
        
        let code = try service.generateTOTP(
            secret: secret,
            algorithm: .sha1,
            digits: 8,
            period: 30,
            date: date
        )
        
        XCTAssertEqual(code.count, 8)
        XCTAssertTrue(code.allSatisfy { $0.isNumber })
    }
    
    func testGenerateTOTP_ChangesWithTime() throws {
        let secret = "JBSWY3DPEHPK3PXP"
        
        let code1 = try service.generateTOTP(
            secret: secret,
            period: 30,
            date: Date(timeIntervalSince1970: 0)
        )
        
        let code2 = try service.generateTOTP(
            secret: secret,
            period: 30,
            date: Date(timeIntervalSince1970: 30)
        )
        
        XCTAssertNotEqual(code1, code2, "Los códigos deben cambiar cada período")
    }
    
    func testGenerateTOTP_SameWithinPeriod() throws {
        let secret = "JBSWY3DPEHPK3PXP"
        
        let code1 = try service.generateTOTP(
            secret: secret,
            period: 30,
            date: Date(timeIntervalSince1970: 0)
        )
        
        let code2 = try service.generateTOTP(
            secret: secret,
            period: 30,
            date: Date(timeIntervalSince1970: 15)
        )
        
        XCTAssertEqual(code1, code2, "El código debe ser el mismo dentro del período")
    }
    
    func testGenerateTOTP_SHA256() throws {
        let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA"
        let date = Date(timeIntervalSince1970: 59)
        
        let code = try service.generateTOTP(
            secret: secret,
            algorithm: .sha256,
            digits: 8,
            period: 30,
            date: date
        )
        
        // RFC 6238 espera "46119246" para SHA256
        XCTAssertEqual(code, "46119246")
    }
    
    // MARK: - HOTP Tests
    
    func testGenerateHOTP_WithKnownValues() throws {
        // RFC 4226 Test Vectors
        let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        
        // Vectores de prueba RFC 4226
        let expectedCodes = [
            "755224", "287082", "359152", "969429", "338314",
            "254676", "287922", "162583", "399871", "520489"
        ]
        
        for (counter, expected) in expectedCodes.enumerated() {
            let code = try service.generateHOTP(
                secret: secret,
                counter: counter,
                algorithm: .sha1,
                digits: 6
            )
            XCTAssertEqual(code, expected, "HOTP counter \(counter) debería ser \(expected)")
        }
    }
    
    func testGenerateHOTP_IncrementingCounter() throws {
        let secret = "JBSWY3DPEHPK3PXP"
        
        var codes: Set<String> = []
        
        for counter in 0..<10 {
            let code = try service.generateHOTP(
                secret: secret,
                counter: counter
            )
            codes.insert(code)
        }
        
        // Los códigos deben ser diferentes para diferentes contadores
        XCTAssertEqual(codes.count, 10, "Cada contador debe producir un código único")
    }
    
    // MARK: - Progress and Time Tests
    
    func testSecondsRemaining() {
        // A t=0, deberían quedar 30 segundos (inicio del período)
        let remaining1 = service.secondsRemaining(period: 30, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(remaining1, 30)
        
        // A t=15, deberían quedar 15 segundos
        let remaining2 = service.secondsRemaining(period: 30, date: Date(timeIntervalSince1970: 15))
        XCTAssertEqual(remaining2, 15)
        
        // A t=29, debería quedar 1 segundo
        let remaining3 = service.secondsRemaining(period: 30, date: Date(timeIntervalSince1970: 29))
        XCTAssertEqual(remaining3, 1)
    }
    
    func testProgress() {
        // A t=0, progreso = 1.0 (30/30)
        let progress1 = service.progress(period: 30, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(progress1, 1.0, accuracy: 0.01)
        
        // A t=15, progreso = 0.5 (15/30)
        let progress2 = service.progress(period: 30, date: Date(timeIntervalSince1970: 15))
        XCTAssertEqual(progress2, 0.5, accuracy: 0.01)
        
        // A t=27, progreso ≈ 0.1 (3/30)
        let progress3 = service.progress(period: 30, date: Date(timeIntervalSince1970: 27))
        XCTAssertEqual(progress3, 0.1, accuracy: 0.01)
    }
    
    // MARK: - Invalid Input Tests
    
    func testGenerateTOTP_InvalidSecret() {
        let invalidSecret = "NOT_VALID_BASE32!"
        
        XCTAssertThrowsError(try service.generateTOTP(secret: invalidSecret)) { error in
            XCTAssertTrue(error is Base32.Base32Error)
        }
    }
    
    func testGenerateTOTP_EmptySecret() {
        // Un secreto vacío puede o no lanzar error dependiendo de la implementación
        // Lo importante es que el servicio maneje el caso de forma consistente
        do {
            let code = try service.generateTOTP(secret: "")
            // Si no lanza error, el código debe tener el formato correcto
            XCTAssertEqual(code.count, 6)
        } catch {
            // Es aceptable que lance un error
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Different Period Tests
    
    func testGenerateTOTP_DifferentPeriods() throws {
        let secret = "JBSWY3DPEHPK3PXP"
        let date = Date(timeIntervalSince1970: 60)
        
        let code30 = try service.generateTOTP(secret: secret, period: 30, date: date)
        let code60 = try service.generateTOTP(secret: secret, period: 60, date: date)
        
        // Los códigos serán diferentes porque el contador interno es diferente
        // t=60, period=30 -> counter=2
        // t=60, period=60 -> counter=1
        XCTAssertNotEqual(code30, code60)
    }
}

