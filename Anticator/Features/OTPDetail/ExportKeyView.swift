//
//  ExportKeyView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 31/3/26.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ExportKeyView: View {
    let account: OTPAccount
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var secret: String?
    @State private var showSecret = false
    @State private var copiedItem: CopiedItem?
    @State private var loadError = false
    
    private let otpAccountService = OTPAccountService.shared
    
    private enum CopiedItem {
        case secret, uri
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let secret {
                    contentView(secret: secret)
                } else if loadError {
                    errorView
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Exportar clave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .onAppear { loadSecret() }
    }
    
    private func contentView(secret: String) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                warningBanner
                qrCodeSection(secret: secret)
                secretSection(secret: secret)
                uriSection(secret: secret)
            }
            .padding()
        }
    }
    
    // MARK: - Warning
    
    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            
            Text("No compartas esta clave con nadie. Quien la tenga podrá generar tus códigos de verificación.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - QR Code
    
    private func qrCodeSection(secret: String) -> some View {
        VStack(spacing: 16) {
            Text("Escanea desde otra app")
                .font(.headline)
            
            let uri = account.otpauthURI(secret: secret)
            if let qrImage = generateQRCode(from: uri) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            }
            
            Text(account.issuer.isEmpty ? account.accountName : account.issuer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Secret Key
    
    private func secretSection(secret: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clave secreta")
                .font(.headline)
            
            HStack {
                Group {
                    if showSecret {
                        Text(secret)
                            .font(.system(size: 15, design: .monospaced))
                    } else {
                        Text(String(repeating: "•", count: min(secret.count, 24)))
                            .font(.system(size: 15, design: .monospaced))
                    }
                }
                .lineLimit(2)
                .textSelection(.enabled)
                
                Spacer()
                
                Button {
                    showSecret.toggle()
                } label: {
                    Image(systemName: showSecret ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            
            Button {
                UIPasteboard.general.string = secret
                withAnimation { copiedItem = .secret }
                clearCopiedFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedItem == .secret ? "checkmark" : "doc.on.doc")
                    Text(copiedItem == .secret ? "Copiada" : "Copiar clave")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(copiedItem == .secret ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1))
                )
                .foregroundStyle(copiedItem == .secret ? .green : .accentColor)
            }
        }
    }
    
    // MARK: - URI
    
    private func uriSection(secret: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URI completa")
                .font(.headline)
            
            let uri = account.otpauthURI(secret: secret)
            
            Text(uri)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                )
                .textSelection(.enabled)
            
            Button {
                UIPasteboard.general.string = uri
                withAnimation { copiedItem = .uri }
                clearCopiedFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedItem == .uri ? "checkmark" : "link")
                    Text(copiedItem == .uri ? "Copiada" : "Copiar URI")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(copiedItem == .uri ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.1))
                )
                .foregroundStyle(copiedItem == .uri ? .green : .accentColor)
            }
        }
    }
    
    // MARK: - Error
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No se pudo obtener la clave")
                .font(.headline)
            Text("La clave secreta no está disponible en el Keychain.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func loadSecret() {
        do {
            secret = try otpAccountService.getSecret(for: account)
        } catch {
            loadError = true
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scale = 10.0
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    private func clearCopiedFeedback() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedItem = nil }
        }
    }
}

#Preview {
    ExportKeyView(
        account: OTPAccount(
            issuer: "Google",
            accountName: "usuario@gmail.com",
            secretKeyRef: "test"
        )
    )
}
