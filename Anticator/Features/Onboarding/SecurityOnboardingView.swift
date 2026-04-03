//
//  SecurityOnboardingView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 1/1/26.
//

import SwiftUI

struct SecurityOnboardingView: View {
    @Environment(AppState.self) private var appState
    
    @State private var showingPINSetup = false
    @State private var selectedOption: SecurityOption?
    @State private var isSettingUp = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 30
    
    private let biometricService = BiometricService.shared
    
    enum SecurityOption {
        case biometric
        case pin
        case later
    }
    
    var biometricType: BiometricService.BiometricType {
        biometricService.availableBiometricType
    }
    
    var body: some View {
        ZStack {
            // Fondo con gradiente
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icono animado
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.accentColor.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 30)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 90, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .accentColor.opacity(0.5), radius: 20, y: 10)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                Spacer()
                    .frame(height: 40)
                
                // Título y descripción
                VStack(spacing: 16) {
                    Text("Protege tus códigos")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(contentOpacity)
                
                Spacer()
                
                // Opciones
                VStack(spacing: 14) {
                    // Biometría (si disponible)
                    if biometricType != .none {
                        Button {
                            setupBiometric()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: biometricType.iconName)
                                    .font(.system(size: 22, weight: .semibold))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Usar \(biometricType.displayName)")
                                        .font(.system(size: 17, weight: .semibold))
                                    Text("Rápido y seguro")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .opacity(0.6)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .padding(.horizontal, 20)
                            .background(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .accentColor.opacity(0.4), radius: 12, y: 6)
                        }
                        .disabled(isSettingUp)
                    }
                    
                    // PIN
                    Button {
                        showingPINSetup = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.grid.3x3")
                                .font(.system(size: 20, weight: .medium))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Configurar PIN")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("4 dígitos")
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .opacity(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSettingUp)
                    
                    // Configurar después
                    Button {
                        skipSetup()
                    } label: {
                        Text("Configurar después")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                    }
                    .disabled(isSettingUp)
                }
                .padding(.horizontal, 24)
                .offset(y: buttonsOffset)
                .opacity(contentOpacity)
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .sheet(isPresented: $showingPINSetup) {
            OnboardingPINSetupView { success in
                if success {
                    completeOnboarding(withAuth: true, useBiometrics: false, withPIN: true)
                }
            }
        }
        .onAppear {
            animateEntrance()
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12),
                    Color(red: 0.08, green: 0.09, blue: 0.15),
                    Color(red: 0.04, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
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
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
            contentOpacity = 1.0
            buttonsOffset = 0
        }
    }
    
    private func setupBiometric() {
        isSettingUp = true
        
        Task {
            let result = await biometricService.authenticate(reason: "Configura \(biometricType.displayName) para proteger tus códigos")
            
            await MainActor.run {
                isSettingUp = false
                
                switch result {
                case .success:
                    completeOnboarding(withAuth: true, useBiometrics: true)
                case .failure:
                    // Usuario canceló o falló, no hacer nada
                    break
                }
            }
        }
    }
    
    private func skipSetup() {
        completeOnboarding(withAuth: false, useBiometrics: false)
    }
    
    private func completeOnboarding(withAuth: Bool, useBiometrics: Bool, withPIN: Bool = false) {
        appState.requireAuthentication = withAuth
        appState.useBiometrics = useBiometrics
        appState.hasSetupPIN = withPIN
        appState.hasCompletedOnboarding = true
        
        // Desbloquear después del onboarding (ya se autenticó al configurar)
        appState.isUnlocked = true
    }
}

// MARK: - Onboarding PIN Setup View
struct OnboardingPINSetupView: View {
    let onComplete: (Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var step = 1
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var error: String?
    
    private let appPINService = AppPINService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text(step == 1 ? "Crea un PIN de 4 dígitos" : "Confirma tu PIN")
                        .font(.title2.bold())
                    
                    PINDots(count: currentPIN.count)
                    
                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    PINKeypad(pin: step == 1 ? $firstPIN : $confirmPIN)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding()
            }
            .navigationTitle("Configurar PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
            .onChange(of: firstPIN) { _, newValue in
                if newValue.count == 4 {
                    step = 2
                    error = nil
                }
            }
            .onChange(of: confirmPIN) { _, newValue in
                if newValue.count == 4 {
                    verifyAndSave()
                }
            }
        }
    }
    
    private var currentPIN: String {
        step == 1 ? firstPIN : confirmPIN
    }
    
    private func verifyAndSave() {
        if firstPIN == confirmPIN {
            do {
                try appPINService.savePIN(firstPIN)
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                onComplete(true)
                dismiss()
            } catch {
                self.error = String(localized: "Error al guardar PIN")
                confirmPIN = ""
            }
        } else {
            error = String(localized: "Los PINs no coinciden")
            confirmPIN = ""
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

#Preview {
    SecurityOnboardingView()
        .environment(AppState())
}

