//
//  ServiceIconMapper.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import Foundation

/// Mapea nombres de issuers a iconos de servicios conocidos
/// Solo se usa desde contextos MainActor (vistas)
@MainActor
enum ServiceIconMapper {
    /// Obtiene el nombre del icono para un issuer dado
    static func iconName(for issuer: String) -> String {
        let normalized = issuer.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Búsqueda exacta
        if let icon = iconMapping[normalized] {
            return icon
        }
        
        // Búsqueda parcial (el issuer contiene el key)
        for (key, icon) in iconMapping {
            if normalized.contains(key) {
                return icon
            }
        }
        
        // Default
        return "default"
    }
    
    /// Lista de todos los iconos disponibles
    static var availableIcons: [String] {
        Array(Set(iconMapping.values)).sorted()
    }
    
    // MARK: - Mapping Data
    
    private static let iconMapping: [String: String] = [
        // Grandes tecnológicas
        "google": "google",
        "gmail": "google",
        "github": "github",
        "gitlab": "gitlab",
        "microsoft": "microsoft",
        "azure": "microsoft",
        "apple": "apple",
        "amazon": "amazon",
        "aws": "amazon",
        
        // Redes sociales
        "facebook": "facebook",
        "meta": "facebook",
        "instagram": "instagram",
        "twitter": "x",
        "x": "x",
        "linkedin": "linkedin",
        "reddit": "reddit",
        "discord": "discord",
        "slack": "slack",
        "telegram": "telegram",
        "whatsapp": "whatsapp",
        "tiktok": "tiktok",
        "snapchat": "snapchat",
        "pinterest": "pinterest",
        
        // Desarrollo
        "bitbucket": "bitbucket",
        "atlassian": "atlassian",
        "jira": "atlassian",
        "confluence": "atlassian",
        "digitalocean": "digitalocean",
        "cloudflare": "cloudflare",
        "vercel": "vercel",
        "docker": "docker",
        
        // Finanzas/Cripto
        "paypal": "paypal",
        "stripe": "stripe",
        "coinbase": "coinbase",
        "binance": "binance",
        
        // Gaming
        "steam": "steam",
        "epicgames": "epicgames",
        "epic games": "epicgames",
        "playstation": "playstation",
        "psn": "playstation",
        "xbox": "xbox",
        "twitch": "twitch",
        
        // Productividad
        "dropbox": "dropbox",
        "notion": "notion",
        "trello": "trello",
        "zoom": "zoom",
        "figma": "figma",
        "adobe": "adobe",
        
        // Email/Hosting
        "protonmail": "protonmail",
        "proton": "protonmail",
        
        // Otros
        "bitwarden": "bitwarden",
        "1password": "1password",
        "spotify": "spotify",
        "netflix": "netflix",
        "hbo": "hbomax",
        "hbo max": "hbomax"
    ]
}
