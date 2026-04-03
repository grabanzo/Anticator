//
//  PINComponents.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

// MARK: - PIN Dots
struct PINDots: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(index < count ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: count)
            }
        }
    }
}

// MARK: - PIN Keypad
struct PINKeypad: View {
    @Binding var pin: String
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...9, id: \.self) { number in
                PINKey(label: "\(number)") {
                    addDigit(number)
                }
            }
            
            // Espacio vacío
            Color.clear
                .frame(height: 70)
            
            PINKey(label: "0") {
                addDigit(0)
            }
            
            // Borrar
            PINKey(label: "delete.left.fill", isSymbol: true) {
                deleteDigit()
            }
        }
    }
    
    private func addDigit(_ digit: Int) {
        guard pin.count < 4 else { return }
        pin += "\(digit)"
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - PIN Key
struct PINKey: View {
    let label: String
    var isSymbol: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: 70, height: 70)
                
                if isSymbol {
                    Image(systemName: label)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text(label)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .buttonStyle(PINKeyButtonStyle())
    }
}

// MARK: - PIN Key Button Style
struct PINKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("PIN Dots") {
    VStack(spacing: 20) {
        PINDots(count: 0)
        PINDots(count: 2)
        PINDots(count: 4)
    }
    .padding()
}

#Preview("PIN Keypad") {
    PINKeypad(pin: .constant(""))
        .padding()
}

