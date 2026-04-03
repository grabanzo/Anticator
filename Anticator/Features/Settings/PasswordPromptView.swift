//
//  PasswordPromptView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct PasswordPromptView: View {
    let title: String
    let message: String
    let confirmButtonTitle: String
    let onConfirm: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isNewPassword = true
    @State private var error: String?
    
    var isValid: Bool {
        if isNewPassword {
            return password.count >= 6 && password == confirmPassword
        }
        return password.count >= 6
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showPassword {
                            TextField("Contraseña", text: $password)
                        } else {
                            SecureField("Contraseña", text: $password)
                        }
                        
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if isNewPassword {
                        SecureField("Confirmar contraseña", text: $confirmPassword)
                    }
                } header: {
                    Text(message)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if password.count > 0 && password.count < 6 {
                            Label("Mínimo 6 caracteres", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        
                        if isNewPassword && !confirmPassword.isEmpty && password != confirmPassword {
                            Label("Las contraseñas no coinciden", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        
                        if let error = error {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                }
                
                if title.lowercased().contains("import") {
                    Section {
                        Toggle("Es una contraseña nueva", isOn: $isNewPassword)
                    } footer: {
                        Text("Activa esta opción si estás configurando la sincronización por primera vez.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) {
                        onConfirm(password)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                // Si es importación o sync, asumir que no es nueva contraseña
                if title.lowercased().contains("import") || title.lowercased().contains("sync") {
                    isNewPassword = false
                }
            }
        }
    }
}

#Preview {
    PasswordPromptView(
        title: "Exportar",
        message: "Introduce una contraseña para cifrar el backup.",
        confirmButtonTitle: "Exportar"
    ) { password in
        print("Password: \(password)")
    }
}

