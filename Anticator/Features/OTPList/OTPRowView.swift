//
//  OTPRowView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct OTPRowView: View {
    let account: OTPAccount
    let currentTime: Date
    
    @State private var code: String = "------"
    @State private var isCopied = false
    @State private var previousCode: String = ""
    
    private let otpGenerator = OTPGeneratorService.shared
    private let otpAccountService = OTPAccountService.shared
    
    var progress: Double {
        otpGenerator.progress(period: account.period, date: currentTime)
    }
    
    var secondsRemaining: Int {
        otpGenerator.secondsRemaining(period: account.period, date: currentTime)
    }
    
    var isUrgent: Bool {
        secondsRemaining <= 5
    }
    
    var isWarning: Bool {
        secondsRemaining <= 10 && secondsRemaining > 5
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icono del servicio
            ServiceIcon(account.resolvedIconName, size: 46)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            
            // Info de la cuenta
            VStack(alignment: .leading, spacing: 3) {
                Text(account.issuer.isEmpty ? "Sin nombre" : account.issuer)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                if !account.accountName.isEmpty {
                    Text(account.accountName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Código y progreso circular
            HStack(spacing: 10) {
                // Código OTP en dos líneas
                VStack(alignment: .trailing, spacing: 0) {
                    Text(codeFirstHalf)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(codeColor)
                    Text(codeSecondHalf)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(codeColor)
                }
                .contentTransition(.numericText(countsDown: true))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: code)
                
                // Progreso circular (solo TOTP)
                if account.type == .totp {
                    ZStack {
                        // Fondo del círculo
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                        
                        // Progreso
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                progressGradient,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                        
                        // Segundos
                        Text("\(secondsRemaining)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(progressColor)
                    }
                    .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.vertical, 10)
        .onAppear {
            updateCode()
        }
        .onChange(of: currentTime) {
            updateCode()
        }
        .overlay(alignment: .center) {
            if isCopied {
                copiedOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
    
    private var codeFirstHalf: String {
        guard code.count >= 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(code[..<mid])
    }
    
    private var codeSecondHalf: String {
        guard code.count >= 6 else { return "" }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(code[mid...])
    }
    
    private var codeColor: Color {
        if isUrgent {
            return .red
        } else if isWarning {
            return .orange
        }
        return .primary
    }
    
    private var progressColor: Color {
        if isUrgent {
            return .red
        } else if isWarning {
            return .orange
        }
        return .accentColor
    }
    
    private var progressGradient: AngularGradient {
        if isUrgent {
            return AngularGradient(
                colors: [.red, .red.opacity(0.5)],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        } else if isWarning {
            return AngularGradient(
                colors: [.orange, .yellow],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(270)
            )
        }
        return AngularGradient(
            colors: [.accentColor, .accentColor.opacity(0.5)],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
    
    private var copiedOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
            Text("Copiado")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
        )
    }
    
    private func updateCode() {
        do {
            let secret = try otpAccountService.getSecret(for: account)
            let newCode = try otpGenerator.generateCode(for: account, secret: secret, date: currentTime)
            if newCode != code {
                previousCode = code
                code = newCode
            }
        } catch {
            code = "Error"
        }
    }
    
    func showCopied() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            isCopied = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

#Preview {
    List {
        OTPRowView(
            account: OTPAccount(
                issuer: "Google",
                accountName: "usuario@gmail.com",
                secretKeyRef: "test"
            ),
            currentTime: Date()
        )
    }
}
