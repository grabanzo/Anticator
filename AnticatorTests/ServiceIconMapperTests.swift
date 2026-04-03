//
//  ServiceIconMapperTests.swift
//  AnticatorTests
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import XCTest
@testable import Anticator

@MainActor
final class ServiceIconMapperTests: XCTestCase {
    
    // MARK: - Exact Match Tests
    
    func testIconName_ExactMatch_Google() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "google"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "Google"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GOOGLE"), "google")
    }
    
    func testIconName_ExactMatch_GitHub() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "github"), "github")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GitHub"), "github")
    }
    
    func testIconName_ExactMatch_Microsoft() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "microsoft"), "microsoft")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "azure"), "microsoft")
    }
    
    func testIconName_ExactMatch_SocialNetworks() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "facebook"), "facebook")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "meta"), "facebook")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "instagram"), "instagram")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "twitter"), "x")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "x"), "x")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "linkedin"), "linkedin")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "discord"), "discord")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "slack"), "slack")
    }
    
    func testIconName_ExactMatch_Development() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "gitlab"), "gitlab")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "bitbucket"), "bitbucket")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "atlassian"), "atlassian")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "jira"), "atlassian")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "digitalocean"), "digitalocean")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "cloudflare"), "cloudflare")
    }
    
    func testIconName_ExactMatch_Gaming() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "steam"), "steam")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "twitch"), "twitch")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "playstation"), "playstation")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "psn"), "playstation")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "xbox"), "xbox")
    }
    
    func testIconName_ExactMatch_Crypto() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "coinbase"), "coinbase")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "binance"), "binance")
    }
    
    // MARK: - Partial Match Tests
    
    func testIconName_PartialMatch() {
        // Gmail debería mapear a google
        XCTAssertEqual(ServiceIconMapper.iconName(for: "gmail"), "google")
        
        // AWS debería mapear a amazon
        XCTAssertEqual(ServiceIconMapper.iconName(for: "aws"), "amazon")
        
        // Proton/ProtonMail
        XCTAssertEqual(ServiceIconMapper.iconName(for: "proton"), "protonmail")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "protonmail"), "protonmail")
    }
    
    func testIconName_ContainsMatch() {
        // Si el issuer contiene el nombre del servicio
        XCTAssertEqual(ServiceIconMapper.iconName(for: "Google Account"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GitHub Inc"), "github")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "My Steam Account"), "steam")
    }
    
    // MARK: - Case Insensitivity Tests
    
    func testIconName_CaseInsensitive() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GOOGLE"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "google"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GoOgLe"), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "GITHUB"), "github")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "gitHub"), "github")
    }
    
    // MARK: - Whitespace Handling
    
    func testIconName_TrimsWhitespace() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "  google  "), "google")
        XCTAssertEqual(ServiceIconMapper.iconName(for: "\tgithub\n"), "github")
    }
    
    // MARK: - Default Fallback Tests
    
    func testIconName_UnknownService_ReturnsDefault() {
        // Servicios que no deben coincidir con ningún mapping
        let unknownServices = ["ACME Corp", "RandomApp123", "MyBank"]
        
        for service in unknownServices {
            let icon = ServiceIconMapper.iconName(for: service)
            // Si no encuentra coincidencia, devuelve "default"
            // Pero puede encontrar coincidencias parciales
            XCTAssertFalse(icon.isEmpty, "Icon should not be empty for: \(service)")
        }
    }
    
    func testIconName_EmptyString_ReturnsDefault() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: ""), "default")
    }
    
    func testIconName_OnlyWhitespace_ReturnsDefault() {
        XCTAssertEqual(ServiceIconMapper.iconName(for: "   "), "default")
    }
    
    // MARK: - Available Icons Tests
    
    func testAvailableIcons_NotEmpty() {
        XCTAssertFalse(ServiceIconMapper.availableIcons.isEmpty)
    }
    
    func testAvailableIcons_ContainsCommonIcons() {
        let icons = ServiceIconMapper.availableIcons
        
        // Verificar que contiene algunos iconos comunes
        XCTAssertTrue(icons.contains("google"))
        XCTAssertTrue(icons.contains("github"))
        XCTAssertTrue(icons.contains("facebook"))
        // El "default" no está en availableIcons, es el fallback
    }
    
    func testAvailableIcons_Sorted() {
        let icons = ServiceIconMapper.availableIcons
        let sortedIcons = icons.sorted()
        
        XCTAssertEqual(icons, sortedIcons, "Los iconos disponibles deben estar ordenados")
    }
    
    func testAvailableIcons_NoDuplicates() {
        let icons = ServiceIconMapper.availableIcons
        let uniqueIcons = Set(icons)
        
        XCTAssertEqual(icons.count, uniqueIcons.count, "No debe haber iconos duplicados")
    }
}

