//
//  OTPType.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

enum OTPType: String, Codable, CaseIterable, Sendable {
    case totp
    case hotp
    
    var displayName: String {
        switch self {
        case .totp: return String(localized: "TOTP (Basado en tiempo)")
        case .hotp: return String(localized: "HOTP (Basado en contador)")
        }
    }
}

enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1
    case sha256
    case sha512
    
    var displayName: String {
        switch self {
        case .sha1: return String(localized: "SHA-1")
        case .sha256: return String(localized: "SHA-256")
        case .sha512: return String(localized: "SHA-512")
        }
    }
}

