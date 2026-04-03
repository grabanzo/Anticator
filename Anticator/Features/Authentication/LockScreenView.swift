//
//  LockScreenView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct LockScreenView: View {
    @Environment(AppState.self) private var appState
    var viewModel: AuthenticationViewModel
    
    @State private var showingPINEntry = false
    @State private var hasAttemptedAuth = false
    @State private var lastAuthTrigger: Int = -1
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 50
    @State private var buttonsOpacity: Double = 0
    
    private let biometricService = BiometricService.shared
    
    var biometricType: BiometricService.BiometricType {
        biometricService.availableBiometricType
    }
    
    var body: some View {
        ZStack {
            // Fondo con gradiente
            backgroundGradient
                .ignoresSafeArea()
            
            // Contenido
            VStack(spacing: 50) {
                Spacer()
                
                // Logo animado
                VStack(spacing: 20) {
                    ZStack {
                        // Círculo de fondo con glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.accentColor.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)
                        
                        // Icono
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .accentColor.opacity(0.5), radius: 20, y: 10)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    
                    VStack(spacing: 8) {
                        Text("Anticator")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Tus códigos protegidos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(logoOpacity)
                }
                
                Spacer()
                
                // Botones de autenticación
                VStack(spacing: 14) {
                    // Biometría
                    if appState.useBiometrics && biometricType != .none {
                        Button {
                            Task {
                                await authenticateWithBiometrics()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: biometricType.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                Text(biometricType.displayName)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .accentColor.opacity(0.4), radius: 10, y: 5)
                        }
                        .disabled(viewModel.isAuthenticating)
                        .opacity(viewModel.isAuthenticating ? 0.7 : 1)
                    }
                    
                    // PIN
                    if appState.hasSetupPIN {
                        Button {
                            showingPINEntry = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.grid.3x3")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Usar PIN")
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    
                    // Error
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .sheet(isPresented: $showingPINEntry) {
            PINEntryView { success in
                if success {
                    appState.isUnlocked = true
                }
            }
        }
        .onAppear {
            animateEntrance()
            // Sincronizar lastAuthTrigger al aparecer para evitar doble disparo
            lastAuthTrigger = appState.authTrigger
            if !hasAttemptedAuth {
                triggerBiometricAuth()
            }
        }
        .onChange(of: appState.authTrigger) { oldValue, newValue in
            // Solo disparar si el trigger cambió DESPUÉS de que la vista apareció
            // y no estamos ya autenticando
            guard newValue != oldValue, 
                  newValue != lastAuthTrigger,
                  !viewModel.isAuthenticating else { return }
            
            lastAuthTrigger = newValue
            triggerBiometricAuth()
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            // Gradiente base
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.08, green: 0.09, blue: 0.15),
                    Color(red: 0.04, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Círculos decorativos
            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 150, y: 300)
        }
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
            buttonsOffset = 0
            buttonsOpacity = 1.0
        }
    }
    
    private func triggerBiometricAuth() {
        guard appState.useBiometrics && 
              biometricType != .none && 
              !viewModel.isAuthenticating &&
              !hasAttemptedAuth else { return }
        
        hasAttemptedAuth = true
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !viewModel.isAuthenticating else { return }
            await authenticateWithBiometrics()
        }
    }
    
    private func authenticateWithBiometrics() async {
        let success = await viewModel.authenticateWithBiometrics()
        if success {
            appState.isUnlocked = true
        }
    }
}

// MARK: - PIN Entry View
struct PINEntryView: View {
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pin = ""
    @State private var error: String?
    @State private var attempts = 0
    @State private var shake = false
    
    private let appPINService = AppPINService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Icono
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Introduce tu PIN")
                        .font(.title2.bold())
                    
                    // Dots del PIN
                    PINDots(count: pin.count)
                        .offset(x: shake ? -10 : 0)
                        .animation(.spring(response: 0.1, dampingFraction: 0.3).repeatCount(3), value: shake)
                    
                    if let error = error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    // Teclado
                    PINKeypad(pin: $pin)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding()
            }
            .navigationTitle("PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
            .onChange(of: pin) { _, newValue in
                if newValue.count == 4 {
                    verifyPIN()
                }
            }
        }
    }
    
    private func verifyPIN() {
        if appPINService.verifyPIN(pin) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onComplete(true)
            dismiss()
        } else {
            attempts += 1
            error = String(localized: "PIN incorrecto (\(attempts)/5)")
            pin = ""
            shake = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                shake = false
            }
            
            if attempts >= 5 {
                error = String(localized: "Demasiados intentos. Intenta más tarde.")
            }
        }
    }
}

#Preview {
    LockScreenView(viewModel: AuthenticationViewModel())
        .environment(AppState())
}
