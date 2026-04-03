//
//  ManualEntryView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftData
import SwiftUI

struct ManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let groupId: UUID?
    let onSave: () -> Void
    
    init(groupId: UUID? = nil, onSave: @escaping () -> Void) {
        self.groupId = groupId
        self.onSave = onSave
    }
    
    @State private var issuer = ""
    @State private var accountName = ""
    @State private var secret = ""
    @State private var type: OTPType = .totp
    @State private var algorithm: OTPAlgorithm = .sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var showAdvanced = false
    
    @State private var error: String?
    @State private var showingError = false
    
    var isValid: Bool {
        !secret.isEmpty && Base32.isValid(secret)
    }
    
    var body: some View {
        Form {
            // Información básica
            Section {
                TextField("Servicio (ej: Google)", text: $issuer)
                    .textContentType(.organizationName)
                    .autocorrectionDisabled()
                
                TextField("Cuenta (ej: usuario@email.com)", text: $accountName)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                TextField("Clave secreta (Base32)", text: $secret)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Información de la cuenta")
            } footer: {
                if !secret.isEmpty && !Base32.isValid(secret) {
                    Label("La clave secreta no es válida", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            
            // Opciones avanzadas
            Section {
                DisclosureGroup("Opciones avanzadas", isExpanded: $showAdvanced) {
                    Picker("Tipo", selection: $type) {
                        ForEach(OTPType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Algoritmo", selection: $algorithm) {
                        ForEach(OTPAlgorithm.allCases, id: \.self) { algo in
                            Text(algo.displayName).tag(algo)
                        }
                    }
                    
                    Picker("Dígitos", selection: $digits) {
                        Text("6 dígitos").tag(6)
                        Text("8 dígitos").tag(8)
                    }
                    
                    if type == .totp {
                        Picker("Período", selection: $period) {
                            Text("30 segundos").tag(30)
                            Text("60 segundos").tag(60)
                        }
                    }
                }
            }
            
            // Botón guardar
            Section {
                Button {
                    saveAccount()
                } label: {
                    HStack {
                        Spacer()
                        Label("Guardar", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!isValid)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error ?? "Error desconocido")
        }
    }
    
    private func saveAccount() {
        do {
            // Create requiere guardar en Keychain - usar Service
            _ = try OTPAccountService.shared.createAccount(
                in: modelContext,
                issuer: issuer.trimmingCharacters(in: .whitespaces),
                accountName: accountName.trimmingCharacters(in: .whitespaces),
                secret: secret.uppercased().replacingOccurrences(of: " ", with: ""),
                type: type,
                algorithm: algorithm,
                digits: digits,
                period: period,
                groupId: groupId
            )
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            onSave()
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        ManualEntryView { }
    }
}

