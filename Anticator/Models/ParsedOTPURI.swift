//
//  ParsedOTPURI.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Representa un OTP parseado desde una URI otpauth://
struct ParsedOTPURI: Sendable {
    let type: OTPType
    let issuer: String
    let accountName: String
    let secret: String
    let algorithm: OTPAlgorithm
    let digits: Int
    let period: Int
    let counter: Int
    
    /// Parsea una URI del formato otpauth://totp/Issuer:account?secret=XXX&...
    static func parse(from urlString: String) throws -> ParsedOTPURI {
        guard let url = URL(string: urlString),
              url.scheme == "otpauth" else {
            throw ParseError.invalidScheme
        }
        
        // Tipo: totp o hotp
        guard let host = url.host,
              let type = OTPType(rawValue: host) else {
            throw ParseError.invalidType
        }
        
        // Label: /Issuer:account o /account
        var path = url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        
        let (issuer, accountName) = parseLabel(path)
        
        // Query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw ParseError.missingParameters
        }
        
        var params: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                params[item.name.lowercased()] = value
            }
        }
        
        // Secret (requerido)
        guard let secret = params["secret"], !secret.isEmpty else {
            throw ParseError.missingSecret
        }
        
        // Validar que el secret es base32 válido
        guard Base32.isValid(secret) else {
            throw ParseError.invalidSecret
        }
        
        // Issuer puede venir en query también
        let finalIssuer = params["issuer"] ?? issuer
        
        // Algorithm (default: SHA1)
        let algorithm: OTPAlgorithm
        if let algoString = params["algorithm"]?.lowercased() {
            switch algoString {
            case "sha1": algorithm = .sha1
            case "sha256": algorithm = .sha256
            case "sha512": algorithm = .sha512
            default: algorithm = .sha1
            }
        } else {
            algorithm = .sha1
        }
        
        // Digits (default: 6)
        let digits = Int(params["digits"] ?? "6") ?? 6
        guard digits == 6 || digits == 8 else {
            throw ParseError.invalidDigits
        }
        
        // Period (default: 30, solo TOTP)
        let period = Int(params["period"] ?? "30") ?? 30
        
        // Counter (solo HOTP)
        let counter = Int(params["counter"] ?? "0") ?? 0
        
        return ParsedOTPURI(
            type: type,
            issuer: finalIssuer,
            accountName: accountName,
            secret: secret.uppercased(),
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter
        )
    }
    
    private static func parseLabel(_ label: String) -> (issuer: String, account: String) {
        let decoded = label.removingPercentEncoding ?? label
        
        if let colonIndex = decoded.firstIndex(of: ":") {
            let issuer = String(decoded[..<colonIndex])
            let account = String(decoded[decoded.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            return (issuer, account)
        }
        
        return ("", decoded)
    }
    
    enum ParseError: LocalizedError, Sendable {
        case invalidScheme
        case invalidType
        case missingParameters
        case missingSecret
        case invalidSecret
        case invalidDigits
        
        var errorDescription: String? {
            switch self {
            case .invalidScheme:
                return "URL inválida. Debe comenzar con otpauth://"
            case .invalidType:
                return "Tipo de OTP inválido. Debe ser totp o hotp."
            case .missingParameters:
                return "Faltan parámetros en la URL."
            case .missingSecret:
                return "Falta el secreto en la URL."
            case .invalidSecret:
                return "El secreto no es válido (debe ser Base32)."
            case .invalidDigits:
                return "Número de dígitos inválido (debe ser 6 u 8)."
            }
        }
    }
}

