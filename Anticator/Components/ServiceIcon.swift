//
//  ServiceIcon.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

// MARK: - Service Icon View
struct ServiceIcon: View {
    let name: String
    let size: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(_ name: String, size: CGFloat = 32) {
        self.name = name
        self.size = size
    }
    
    private var brandColor: Color {
        Self.brandColors[name] ?? colorForName(name)
    }
    
    var body: some View {
        Group {
            if let uiImage = UIImage(named: "ServiceIcons/\(name)") {
                // Icono con fondo de color de marca
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .fill(brandColor)
                    
                    Image(uiImage: uiImage)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.white)
                        .padding(size * 0.15)
                }
            } else {
                // Fallback: primera letra del nombre
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .fill(colorForName(name))
                    
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
    }
    
    private func colorForName(_ name: String) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .red, .orange,
            .green, .teal, .cyan, .indigo
        ]
        
        let hash = name.lowercased().unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count]
    }
}

// MARK: - Brand Colors
extension ServiceIcon {
    static let brandColors: [String: Color] = [
        "google": Color(red: 0.92, green: 0.26, blue: 0.21),
        "github": Color(red: 0.09, green: 0.09, blue: 0.09),
        "gitlab": Color(red: 0.99, green: 0.40, blue: 0.14),
        "microsoft": Color(red: 0.00, green: 0.47, blue: 0.84),
        "apple": Color(red: 0.00, green: 0.00, blue: 0.00),
        "amazon": Color(red: 1.00, green: 0.60, blue: 0.00),
        "facebook": Color(red: 0.00, green: 0.60, blue: 0.93),
        "instagram": Color(red: 0.88, green: 0.19, blue: 0.42),
        "x": Color(red: 0.00, green: 0.00, blue: 0.00),
        "linkedin": Color(red: 0.00, green: 0.47, blue: 0.71),
        "reddit": Color(red: 1.00, green: 0.27, blue: 0.00),
        "discord": Color(red: 0.34, green: 0.40, blue: 0.95),
        "slack": Color(red: 0.31, green: 0.15, blue: 0.44),
        "telegram": Color(red: 0.16, green: 0.65, blue: 0.88),
        "whatsapp": Color(red: 0.15, green: 0.68, blue: 0.38),
        "tiktok": Color(red: 0.00, green: 0.00, blue: 0.00),
        "snapchat": Color(red: 1.00, green: 0.99, blue: 0.00),
        "pinterest": Color(red: 0.74, green: 0.04, blue: 0.17),
        "bitbucket": Color(red: 0.13, green: 0.39, blue: 0.96),
        "atlassian": Color(red: 0.13, green: 0.39, blue: 0.96),
        "digitalocean": Color(red: 0.00, green: 0.41, blue: 0.87),
        "cloudflare": Color(red: 0.96, green: 0.51, blue: 0.13),
        "vercel": Color(red: 0.00, green: 0.00, blue: 0.00),
        "docker": Color(red: 0.13, green: 0.59, blue: 0.95),
        "paypal": Color(red: 0.00, green: 0.19, blue: 0.54),
        "stripe": Color(red: 0.39, green: 0.33, blue: 0.98),
        "coinbase": Color(red: 0.00, green: 0.33, blue: 0.98),
        "binance": Color(red: 0.95, green: 0.73, blue: 0.11),
        "steam": Color(red: 0.00, green: 0.00, blue: 0.00),
        "epicgames": Color(red: 0.00, green: 0.00, blue: 0.00),
        "playstation": Color(red: 0.00, green: 0.22, blue: 0.65),
        "xbox": Color(red: 0.07, green: 0.49, blue: 0.04),
        "twitch": Color(red: 0.57, green: 0.27, blue: 1.00),
        "dropbox": Color(red: 0.00, green: 0.38, blue: 1.00),
        "notion": Color(red: 0.00, green: 0.00, blue: 0.00),
        "trello": Color(red: 0.00, green: 0.47, blue: 0.84),
        "zoom": Color(red: 0.17, green: 0.54, blue: 0.97),
        "figma": Color(red: 0.96, green: 0.26, blue: 0.21),
        "adobe": Color(red: 1.00, green: 0.00, blue: 0.00),
        "protonmail": Color(red: 0.42, green: 0.29, blue: 0.78),
        "bitwarden": Color(red: 0.09, green: 0.30, blue: 0.56),
        "1password": Color(red: 0.00, green: 0.46, blue: 0.86),
        "spotify": Color(red: 0.12, green: 0.84, blue: 0.38),
        "netflix": Color(red: 0.89, green: 0.07, blue: 0.14),
        "hbomax": Color(red: 0.00, green: 0.00, blue: 0.00)
    ]
}

#Preview {
    VStack(spacing: 16) {
        ServiceIcon("google", size: 48)
        ServiceIcon("github", size: 48)
        ServiceIcon("unknown", size: 48)
    }
}

