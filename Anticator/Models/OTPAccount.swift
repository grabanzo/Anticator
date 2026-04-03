//
//  OTPAccount.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation
import SwiftData

@Model
final class OTPAccount {
    @Attribute(.unique) var id: UUID
    var issuer: String
    var accountName: String
    var secretKeyRef: String // Referencia al Keychain, no el secreto real
    var type: OTPType
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int
    var counter: Int
    var iconName: String?
    var groupId: UUID? // Grupo al que pertenece
    var order: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    
    init(
        id: UUID = UUID(),
        issuer: String,
        accountName: String,
        secretKeyRef: String,
        type: OTPType = .totp,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30,
        counter: Int = 0,
        iconName: String? = nil,
        groupId: UUID? = nil,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.issuer = issuer
        self.accountName = accountName
        self.secretKeyRef = secretKeyRef
        self.type = type
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
        self.counter = counter
        self.iconName = iconName
        self.groupId = groupId
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    var displayName: String {
        if issuer.isEmpty {
            return accountName
        }
        return "\(issuer) (\(accountName))"
    }
}
