//
//  Base32.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Utilidad para codificar/decodificar Base32 (RFC 4648)
/// Thread-safe - todas las funciones son puras
enum Base32: Sendable {
    private static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    private static let alphabetArray = Array(alphabet)
    
    /// Decodifica un string Base32 a Data
    static func decode(_ string: String) throws -> Data {
        let normalized = string
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
        
        guard isValid(normalized) else {
            throw Base32Error.invalidCharacter
        }
        
        var result = Data()
        var buffer: UInt64 = 0
        var bitsInBuffer = 0
        
        for char in normalized {
            guard let index = alphabet.firstIndex(of: char) else {
                throw Base32Error.invalidCharacter
            }
            
            let value = UInt64(alphabet.distance(from: alphabet.startIndex, to: index))
            buffer = (buffer << 5) | value
            bitsInBuffer += 5
            
            while bitsInBuffer >= 8 {
                bitsInBuffer -= 8
                let byte = UInt8((buffer >> bitsInBuffer) & 0xFF)
                result.append(byte)
            }
        }
        
        return result
    }
    
    /// Codifica Data a string Base32
    static func encode(_ data: Data) -> String {
        var result = ""
        var buffer: UInt64 = 0
        var bitsInBuffer = 0
        
        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bitsInBuffer += 8
            
            while bitsInBuffer >= 5 {
                bitsInBuffer -= 5
                let index = Int((buffer >> bitsInBuffer) & 0x1F)
                result.append(alphabetArray[index])
            }
        }
        
        // Manejar bits restantes
        if bitsInBuffer > 0 {
            let index = Int((buffer << (5 - bitsInBuffer)) & 0x1F)
            result.append(alphabetArray[index])
        }
        
        return result
    }
    
    /// Verifica si un string es Base32 válido
    static func isValid(_ string: String) -> Bool {
        let normalized = string
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
        
        let validChars = CharacterSet(charactersIn: alphabet)
        return normalized.unicodeScalars.allSatisfy { validChars.contains($0) }
    }
    
    enum Base32Error: LocalizedError, Sendable {
        case invalidCharacter
        
        var errorDescription: String? {
            switch self {
            case .invalidCharacter:
                return "El string contiene caracteres Base32 inválidos."
            }
        }
    }
}

