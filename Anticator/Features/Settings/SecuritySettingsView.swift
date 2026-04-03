//
//  SecuritySettingsView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct SecuritySettingsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var showingPINSetup = false
    @State private var showingPINChange = false
    @State private var showingDisableConfirmation = false
    
    private let biometricService = BiometricService.shared
    
    var biometricType: BiometricService.BiometricType {
        biometricService.availableBiometricType
    }
    
    /// Verifica si hay al menos un método de autenticación configurado
    private var hasAuthMethod: Bool {
        (biometricType != .none && appState.useBiometrics) || appState.hasSetupPIN
    }
    
    var body: some View {
        @Bindable var appState = appState
        List {
            // Requerir autenticación
            Section {
                Toggle("Requerir autenticación", isOn: Binding(
                    get: { appState.requireAuthentication },
                    set: { newValue in
                        if newValue {
                            appState.requireAuthentication = true
                        } else {
                            // Al desactivar, pedir confirmación
                            showingDisableConfirmation = true
                        }
                    }
                ))
            } footer: {
                if appState.requireAuthentication && !hasAuthMethod {
                    Text("Configura al menos un método de autenticación.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Si está activado, deberás autenticarte cada vez que abras la app.")
                }
            }
            
            // Métodos de autenticación (solo visible si auth está activo)
            if appState.requireAuthentication {
                Section {
                    // Biometría
                    if biometricType != .none {
                        Toggle(isOn: $appState.useBiometrics) {
                            Label {
                                Text(biometricType.displayName)
                            } icon: {
                                Image(systemName: biometricType.iconName)
                            }
                        }
                        .onChange(of: appState.useBiometrics) { _, newValue in
                            if newValue {
                                // Al activar, mantener desbloqueado (ya estamos dentro)
                                appState.isUnlocked = true
                            } else if !appState.hasSetupPIN {
                                // Si se desactiva el último método, desactivar auth
                                appState.requireAuthentication = false
                                appState.isUnlocked = true
                            }
                        }
                    }
                    
                    // PIN
                    if appState.hasSetupPIN {
                        Button {
                            showingPINChange = true
                        } label: {
                            Label("Cambiar PIN", systemImage: "lock.rotation")
                        }
                        
                        Button(role: .destructive) {
                            removePIN()
                        } label: {
                            Label("Eliminar PIN", systemImage: "trash")
                        }
                    } else {
                        Button {
                            showingPINSetup = true
                        } label: {
                            Label("Configurar PIN", systemImage: "lock")
                        }
                    }
                } header: {
                    Text("Métodos de autenticación")
                }
            }
        }
        .navigationTitle("Seguridad")
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView(mode: .setup) { success in
                if success {
                    appState.hasSetupPIN = true
                    // Mantener desbloqueado (ya estamos dentro)
                    appState.isUnlocked = true
                }
            }
        }
        .sheet(isPresented: $showingPINChange) {
            PINSetupView(mode: .change) { _ in }
        }
        .confirmationDialog(
            "¿Desactivar autenticación?",
            isPresented: $showingDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Desactivar", role: .destructive) {
                appState.requireAuthentication = false
                appState.isUnlocked = true
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Cualquier persona con acceso a tu dispositivo podrá ver tus códigos de autenticación.")
        }
    }
    
    private func removePIN() {
        try? AppPINService.shared.removePIN()
        appState.hasSetupPIN = false
        
        // Si no hay otro método disponible, desactivar autenticación
        if !hasAuthMethod {
            appState.requireAuthentication = false
            appState.isUnlocked = true
        }
    }
}

// MARK: - PIN Setup View
struct PINSetupView: View {
    enum Mode {
        case setup
        case change
    }
    
    let mode: Mode
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var step = 0
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var currentPIN = "" // Para cambio de PIN
    @State private var error: String?
    
    private let appPINService = AppPINService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Icono
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                
                // Título según paso
                Text(stepTitle)
                    .font(.title2.bold())
                
                // Indicador de PIN
                PINDots(count: currentInput.count)
                
                // Teclado numérico
                PINKeypad(pin: currentInputBinding)
                
                // Error
                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(mode == .setup ? "Configurar PIN" : "Cambiar PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
            .onChange(of: currentInput) { _, newValue in
                if newValue.count == 4 {
                    handlePINEntered()
                }
            }
        }
    }
    
    private var stepTitle: String {
        if mode == .change && step == 0 {
            return "Introduce tu PIN actual"
        }
        
        switch step {
        case 0, 1:
            return "Introduce un PIN de 4 dígitos"
        case 2:
            return "Confirma tu PIN"
        default:
            return ""
        }
    }
    
    private var currentInput: String {
        if mode == .change && step == 0 {
            return currentPIN
        }
        return step <= 1 ? firstPIN : confirmPIN
    }
    
    private var currentInputBinding: Binding<String> {
        if mode == .change && step == 0 {
            return $currentPIN
        }
        return step <= 1 ? $firstPIN : $confirmPIN
    }
    
    private func handlePINEntered() {
        error = nil
        
        if mode == .change && step == 0 {
            // Verificar PIN actual
            if appPINService.verifyPIN(currentPIN) {
                step = 1
                currentPIN = ""
            } else {
                error = String(localized: "PIN incorrecto")
                currentPIN = ""
            }
            return
        }
        
        if step <= 1 {
            // Primer PIN introducido
            step = 2
        } else {
            // Confirmar PIN
            if firstPIN == confirmPIN {
                savePIN()
            } else {
                error = String(localized: "Los PINs no coinciden")
                confirmPIN = ""
            }
        }
    }
    
    private func savePIN() {
        do {
            try appPINService.savePIN(firstPIN)
            onComplete(true)
            dismiss()
        } catch {
            self.error = String(localized: "Error al guardar PIN")
        }
    }
}

// PIN Components are defined in LockScreenView.swift

#Preview {
    NavigationStack {
        SecuritySettingsView()
            .environment(AppState())
    }
}

