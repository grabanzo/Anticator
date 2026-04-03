//
//  OTPGeneratorService.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import CryptoKit

/// Servicio para generar códigos TOTP/HOTP
/// Thread-safe y accesible desde cualquier contexto
final class OTPGeneratorService: Sendable {
    static let shared = OTPGeneratorService()
    
    private init() {}
    
    /// Genera un código TOTP basado en el tiempo actual
    func generateTOTP(
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        date: Date = Date()
    ) throws -> String {
        let secretData = try Base32.decode(secret)
        let counter = UInt64(date.timeIntervalSince1970) / UInt64(period)
        return try generateOTP(secret: secretData, counter: counter, algorithm: algorithm, digits: digits)
    }
    
    /// Genera un código HOTP basado en un contador
    func generateHOTP(
        secret: String,
        counter: Int,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6
    ) throws -> String {
        let secretData = try Base32.decode(secret)
        return try generateOTP(secret: secretData, counter: UInt64(counter), algorithm: algorithm, digits: digits)
    }
    
    /// Genera el código OTP usando HMAC
    private func generateOTP(
        secret: Data,
        counter: UInt64,
        algorithm: OTPAlgorithm,
        digits: Int
    ) throws -> String {
        // Convertir counter a big-endian bytes
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)
        
        // Calcular HMAC según el algoritmo
        let hmacData: Data
        let key = SymmetricKey(data: secret)
        
        switch algorithm {
        case .sha1:
            let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
            hmacData = Data(hmac)
        case .sha256:
            let hmac = HMAC<SHA256>.authenticationCode(for: counterData, using: key)
            hmacData = Data(hmac)
        case .sha512:
            let hmac = HMAC<SHA512>.authenticationCode(for: counterData, using: key)
            hmacData = Data(hmac)
        }
        
        // Dynamic truncation
        let offset = Int(hmacData[hmacData.count - 1] & 0x0F)
        let truncatedHash = hmacData.subdata(in: offset..<(offset + 4))
        
        var number = truncatedHash.withUnsafeBytes { ptr -> UInt32 in
            ptr.load(as: UInt32.self).bigEndian
        }
        number &= 0x7FFFFFFF // Quitar el bit de signo
        
        // Calcular el código con el número de dígitos
        let mod = UInt32(pow(10, Double(digits)))
        let code = number % mod
        
        // Formatear con ceros a la izquierda
        return String(format: "%0\(digits)d", code)
    }
    
    /// Calcula los segundos restantes para el siguiente código TOTP
    func secondsRemaining(period: Int = 30, date: Date = Date()) -> Int {
        let seconds = Int(date.timeIntervalSince1970)
        return period - (seconds % period)
    }
    
    /// Calcula el progreso (0.0 a 1.0) del período actual
    func progress(period: Int = 30, date: Date = Date()) -> Double {
        let remaining = Double(secondsRemaining(period: period, date: date))
        return remaining / Double(period)
    }
}

// MARK: - Convenience methods for OTPAccount
extension OTPGeneratorService {
    func generateCode(for account: OTPAccount, secret: String, date: Date = Date()) throws -> String {
        switch account.type {
        case .totp:
            return try generateTOTP(
                secret: secret,
                algorithm: account.algorithm,
                digits: account.digits,
                period: account.period,
                date: date
            )
        case .hotp:
            return try generateHOTP(
                secret: secret,
                counter: account.counter,
                algorithm: account.algorithm,
                digits: account.digits
            )
        }
    }
}

