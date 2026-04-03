//
//  OTPAccount+Export.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

// MARK: - Exportable Version
extension OTPAccount {
    struct Exportable: Codable, Sendable {
        let id: UUID
        let issuer: String
        let accountName: String
        let secret: String // El secreto real para export
        let type: OTPType
        let algorithm: OTPAlgorithm
        let digits: Int
        let period: Int
        let counter: Int
        let iconName: String?
        let order: Int
        let createdAt: Date
        let updatedAt: Date
        let deletedAt: Date?
        let groupId: UUID?
        
        // Init explícito para crear instancias
        nonisolated init(
            id: UUID,
            issuer: String,
            accountName: String,
            secret: String,
            type: OTPType,
            algorithm: OTPAlgorithm,
            digits: Int,
            period: Int,
            counter: Int,
            iconName: String?,
            order: Int,
            createdAt: Date,
            updatedAt: Date,
            deletedAt: Date?,
            groupId: UUID?
        ) {
            self.id = id
            self.issuer = issuer
            self.accountName = accountName
            self.secret = secret
            self.type = type
            self.algorithm = algorithm
            self.digits = digits
            self.period = period
            self.counter = counter
            self.iconName = iconName
            self.order = order
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.groupId = groupId
        }
        
        // Para compatibilidad con backups antiguos sin groupId
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            issuer = try container.decode(String.self, forKey: .issuer)
            accountName = try container.decode(String.self, forKey: .accountName)
            secret = try container.decode(String.self, forKey: .secret)
            type = try container.decode(OTPType.self, forKey: .type)
            algorithm = try container.decode(OTPAlgorithm.self, forKey: .algorithm)
            digits = try container.decode(Int.self, forKey: .digits)
            period = try container.decode(Int.self, forKey: .period)
            counter = try container.decode(Int.self, forKey: .counter)
            iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
            order = try container.decode(Int.self, forKey: .order)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
            deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
            groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        }
    }
    
    func toExportable(secret: String) -> Exportable {
        Exportable(
            id: id,
            issuer: issuer,
            accountName: accountName,
            secret: secret,
            type: type,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter,
            iconName: iconName,
            order: order,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            groupId: groupId
        )
    }
    
    /// Genera la URI otpauth:// estándar para exportar/compartir la cuenta
    func otpauthURI(secret: String) -> String {
        let typeStr = type.rawValue
        let encodedIssuer = issuer.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? issuer
        let encodedAccount = accountName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? accountName
        
        let label: String
        if issuer.isEmpty {
            label = encodedAccount
        } else {
            label = "\(encodedIssuer):\(encodedAccount)"
        }
        
        var params = [
            "secret=\(secret)",
            "issuer=\(issuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? issuer)"
        ]
        
        if algorithm != .sha1 {
            params.append("algorithm=\(algorithm.rawValue.uppercased())")
        }
        if digits != 6 {
            params.append("digits=\(digits)")
        }
        if type == .totp && period != 30 {
            params.append("period=\(period)")
        }
        if type == .hotp {
            params.append("counter=\(counter)")
        }
        
        return "otpauth://\(typeStr)/\(label)?\(params.joined(separator: "&"))"
    }
}

