//
//  OTPDetailView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData
import Combine

struct OTPDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \OTPGroup.order) private var groups: [OTPGroup]
    
    let account: OTPAccount
    
    @State private var issuer: String
    @State private var accountName: String
    @State private var selectedIcon: String
    @State private var selectedGroupId: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var showingExportKey = false
    @State private var hasChanges = false
    
    init(account: OTPAccount) {
        self.account = account
        _issuer = State(initialValue: account.issuer)
        _accountName = State(initialValue: account.accountName)
        _selectedIcon = State(initialValue: account.resolvedIconName)
        _selectedGroupId = State(initialValue: account.groupId)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Preview del código
                Section {
                    OTPPreviewCard(account: account)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Información editable
                Section("Información") {
                    TextField("Servicio", text: $issuer)
                        .onChange(of: issuer) { hasChanges = true }
                    
                    TextField("Cuenta", text: $accountName)
                        .onChange(of: accountName) { hasChanges = true }
                }
                
                // Grupo
                Section("Grupo") {
                    Picker("Grupo", selection: $selectedGroupId) {
                        ForEach(groups) { group in
                            Label {
                                Text(group.name)
                            } icon: {
                                Image(systemName: group.iconName)
                                    .foregroundStyle(group.color)
                            }
                            .tag(group.id as UUID?)
                        }
                    }
                    .onChange(of: selectedGroupId) { hasChanges = true }
                }
                
                // Detalles técnicos (solo lectura)
                Section("Detalles técnicos") {
                    LabeledContent("Tipo", value: account.type.displayName)
                    LabeledContent("Algoritmo", value: account.algorithm.displayName)
                    LabeledContent("Dígitos", value: "\(account.digits)")
                    
                    if account.type == .totp {
                        LabeledContent("Período", value: "\(account.period) segundos")
                    } else {
                        LabeledContent("Contador", value: "\(account.counter)")
                    }
                }
                
                // Exportar
                Section {
                    Button {
                        showingExportKey = true
                    } label: {
                        Label("Exportar clave", systemImage: "square.and.arrow.up")
                    }
                }
                
                // Acciones
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Eliminar cuenta", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                }
            }
            .sheet(isPresented: $showingExportKey) {
                ExportKeyView(account: account)
            }
            .confirmationDialog(
                "¿Eliminar esta cuenta?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Esta acción no se puede deshacer. Perderás el acceso al código de autenticación.")
            }
        }
    }
    
    private func saveChanges() {
        // Actualización simple - modelContext directo
        account.issuer = issuer
        account.accountName = accountName
        if selectedIcon != account.resolvedIconName {
            account.iconName = selectedIcon
        }
        account.groupId = selectedGroupId
        account.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteAccount() {
        // Delete requiere limpiar Keychain - usar Service
        try? OTPAccountService.shared.deleteAccount(account, in: modelContext)
        dismiss()
    }
}

// MARK: - Preview Card
struct OTPPreviewCard: View {
    let account: OTPAccount
    
    @State private var code = "------"
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let otpGenerator = OTPGeneratorService.shared
    private let otpAccountService = OTPAccountService.shared
    
    var progress: Double {
        otpGenerator.progress(period: account.period, date: currentTime)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ServiceIcon(account.resolvedIconName, size: 64)
            
            Text(formattedCode)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .contentTransition(.numericText())
            
            if account.type == .totp {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding()
        .onReceive(timer) { time in
            currentTime = time
            updateCode()
        }
        .onAppear {
            updateCode()
        }
    }
    
    private var formattedCode: String {
        guard code.count >= 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<mid]) \(code[mid...])"
    }
    
    private func updateCode() {
        do {
            let secret = try otpAccountService.getSecret(for: account)
            code = try otpGenerator.generateCode(for: account, secret: secret, date: currentTime)
        } catch {
            code = "Error"
        }
    }
}

#Preview {
    OTPDetailView(
        account: OTPAccount(
            issuer: "Google",
            accountName: "usuario@gmail.com",
            secretKeyRef: "test"
        )
    )
}

