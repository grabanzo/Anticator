//
//  ProtectedGroupPINSheet.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 4/1/26.
//

import SwiftUI
import SwiftData

// MARK: - Enums

/// Acción a realizar con la contraseña del backup
enum BackupPasswordAction {
    case export
    case `import`
}

/// Resultado de la acción sobre un grupo protegido durante import
enum ProtectedGroupImportAction {
    case imported(imported: Int, skipped: Int)
    case skipped(accountCount: Int)
    case cancelled
}

// MARK: - Protected Group PIN Sheet

/// Sheet para solicitar el PIN de un grupo protegido durante import
struct ProtectedGroupPINSheet: View {
    let group: PendingProtectedGroup
    let groupNumber: Int
    let totalGroups: Int
    let onAction: (ProtectedGroupImportAction) -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [OTPAccount]
    
    @State private var pin = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                progressSection
                groupInfoCard
                pinEntrySection
                Spacer()
                actionButtons
            }
            .padding()
            .navigationTitle("Grupo protegido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onAction(.cancelled)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
    
    // MARK: - Subviews
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Grupo \(groupNumber) de \(totalGroups)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ProgressView(value: Double(groupNumber - 1), total: Double(totalGroups))
                .tint(.blue)
        }
    }
    
    private var groupInfoCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "folder.fill.badge.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
            
            Text(group.groupName)
                .font(.title2.bold())
            
            Text(String(localized: "\(group.accountCount) cuenta\(group.accountCount == 1 ? "" : "s") cifrada\(group.accountCount == 1 ? "" : "s")"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var pinEntrySection: some View {
        VStack(spacing: 12) {
            Text(String(localized: "Introduce el PIN del grupo"))
                .font(.headline)
            
            SecureField("PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.center)
                .font(.title3.monospaced())
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(String(localized: "PIN usado al crear el backup"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                importWithPIN()
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(String(localized: "Desbloquear e importar"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pin.isEmpty || isProcessing)
            
            Button("Omitir este grupo") {
                onAction(.skipped(accountCount: group.accountCount))
            }
            .foregroundStyle(.secondary)
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Actions
    
    private func importWithPIN() {
        isProcessing = true
        errorMessage = nil
        
        do {
            let result = try ExportImportService.shared.importProtectedAccounts(
                group,
                pin: pin,
                targetGroupId: group.groupId,
                existingAccounts: Array(accounts),
                context: modelContext
            )
            
            onAction(.imported(imported: result.imported, skipped: result.skipped))
            
        } catch ImportError.wrongPIN {
            errorMessage = String(localized: "PIN incorrecto")
            pin = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
}

#Preview {
    ProtectedGroupPINSheet(
        group: PendingProtectedGroup(
            groupId: UUID(),
            groupName: "Personal",
            accountCount: 5,
            protectedData: ProtectedGroupAccounts(
                groupId: UUID(),
                groupName: "Personal",
                accountCount: 5,
                salt: "",
                iv: "",
                encrypted: "",
                authTag: ""
            )
        ),
        groupNumber: 1,
        totalGroups: 2
    ) { _ in }
}

