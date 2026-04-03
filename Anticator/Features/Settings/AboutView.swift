//
//  AboutView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            // App Info
            Section {
                LabeledContent("Versión", value: Constants.App.version)
                
                Link(destination: Constants.App.githubURL) {
                    HStack {
                        Label("Código fuente", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Cómo funciona
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(
                        icon: "qrcode.viewfinder",
                        title: "Escanea o añade manualmente",
                        description: "Añade tus cuentas escaneando códigos QR o introduciendo los datos manualmente."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "number.circle",
                        title: "Códigos temporales",
                        description: "Se generan códigos TOTP de 6 dígitos que cambian cada 30 segundos, siguiendo el estándar RFC 6238."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "folder.fill",
                        title: "Organiza en grupos",
                        description: "Crea grupos para organizar tus cuentas. Puedes proteger grupos sensibles con PIN."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "arrow.clockwise.icloud",
                        title: "Backup cifrado",
                        description: "Exporta tus cuentas a un archivo cifrado AES-256. Guárdalo donde quieras: iCloud, Dropbox, disco local..."
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Cómo funciona")
            }
            
            // Seguridad de los datos
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(
                        icon: "key.viewfinder",
                        title: "Keychain de iOS",
                        description: "Los secretos de tus cuentas se guardan en el Keychain del sistema, el almacén seguro de Apple protegido por hardware."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "faceid",
                        title: "Biometría",
                        description: "Protege el acceso con Face ID o Touch ID. También puedes usar un PIN como alternativa."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "lock.shield",
                        title: "Cifrado AES-256",
                        description: "Los backups se cifran con AES-256-GCM y tu contraseña usando PBKDF2 con 100,000 iteraciones."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "wifi.slash",
                        title: "100% Offline",
                        description: "La app funciona completamente sin internet. Tus datos nunca salen de tu dispositivo."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "hand.raised.slash",
                        title: "Sin tracking",
                        description: "No recopilamos ningún dato. Sin analytics, sin anuncios, sin telemetría."
                    )
                    
                    Divider()
                    
                    infoRow(
                        icon: "eye.slash",
                        title: "Código abierto",
                        description: "El código fuente está disponible en GitHub. Puedes auditarlo tú mismo."
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Seguridad de los datos")
            }
        }
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

