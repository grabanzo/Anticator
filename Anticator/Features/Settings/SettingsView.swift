//
//  SettingsView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - UI State
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var showingPasswordPrompt = false
    @State private var passwordAction: BackupPasswordAction = .export
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingLockedGroupsAlert = false
    @State private var exportDocument: BackupDocument?
    @State private var pendingImportURL: URL?
    
    // MARK: - Protected Groups Import State
    // El estado vive aquí (no en el sheet) para evitar pérdida por re-renders
    @State private var protectedGroupsToImport: [PendingProtectedGroup] = []
    @State private var currentProtectedGroupIndex = 0
    @State private var protectedImportStats: (imported: Int, skipped: Int) = (0, 0)
    @State private var baseImportResult: ImportResult?
    @State private var showingProtectedGroupPIN = false
    
    @Query private var accounts: [OTPAccount]
    @Query(sort: \OTPGroup.order) private var groups: [OTPGroup]
    
    private let groupService = GroupService.shared
    
    /// Grupos que tienen PIN configurado y están bloqueados
    private var lockedGroups: [OTPGroup] {
        groups.filter { group in
            group.requiresPIN && 
            groupService.hasPIN(for: group) && 
            !appState.isGroupUnlocked(group.id)
        }
    }
    
    private var hasLockedGroups: Bool {
        !lockedGroups.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Grupos
                Section {
                    NavigationLink {
                        GroupManagerView()
                    } label: {
                        Label("Gestionar grupos", systemImage: "folder.badge.gearshape")
                    }
                } footer: {
                    Text(String(localized: "\(groups.count) grupo\(groups.count == 1 ? "" : "s"). Organiza tus códigos en grupos."))
                }
                
                // Seguridad
                Section {
                    NavigationLink {
                        SecuritySettingsView()
                    } label: {
                        Label("Seguridad", systemImage: "lock.shield")
                    }
                } footer: {
                    Text("Configura Face ID, Touch ID o PIN para proteger tus códigos.")
                }
                
                // Backup
                Section {
                    Button {
                        if hasLockedGroups {
                            showingLockedGroupsAlert = true
                        } else {
                            passwordAction = .export
                            showingPasswordPrompt = true
                        }
                    } label: {
                        Label("Crear backup", systemImage: "square.and.arrow.up")
                    }
                    .disabled(accounts.isEmpty)
                    
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Restaurar backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    if accounts.isEmpty {
                        Text("No hay cuentas para exportar.")
                            .foregroundStyle(.orange)
                    } else {
                        Text(String(localized: "\(accounts.count) cuenta\(accounts.count == 1 ? "" : "s") disponible\(accounts.count == 1 ? "" : "s") para backup."))
                    }
                }
                
                // Apariencia
                Section {
                    LabeledContent("Tema", value: "Automático")
                } header: {
                    Text("Apariencia")
                }
                
                // Acerca de
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Acerca de Anticator", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Ajustes")
            .sheet(isPresented: $showingPasswordPrompt) {
                PasswordPromptView(
                    title: passwordAction == .export ? "Crear Backup" : "Restaurar Backup",
                    message: passwordAction == .export
                        ? "Introduce una contraseña para cifrar el archivo."
                        : "Introduce la contraseña del archivo.",
                    confirmButtonTitle: passwordAction == .export ? "Continuar" : "Restaurar"
                ) { password in
                    handlePasswordEntered(password)
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.data, .json, UTType(filenameExtension: Constants.Backup.fileExtension) ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleImportFile(result)
            }
            .fileExporter(
                isPresented: $showingExportPicker,
                document: exportDocument,
                contentType: UTType(filenameExtension: Constants.Backup.fileExtension) ?? .json,
                defaultFilename: "\(Constants.App.name)_backup_\(dateString)"
            ) { result in
                handleExportResult(result)
            }
            .alert("Resultado", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Grupos protegidos bloqueados", isPresented: $showingLockedGroupsAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                let groupNames = lockedGroups.map { $0.name }.joined(separator: ", ")
                Text(String(localized: "Los siguientes grupos están bloqueados:\n\n\(groupNames)\n\nDesbloquéalos primero para incluirlos en el backup."))
            }
            .sheet(isPresented: $showingProtectedGroupPIN) {
                if currentProtectedGroupIndex < protectedGroupsToImport.count {
                    ProtectedGroupPINSheet(
                        group: protectedGroupsToImport[currentProtectedGroupIndex],
                        groupNumber: currentProtectedGroupIndex + 1,
                        totalGroups: protectedGroupsToImport.count
                    ) { action in
                        handleProtectedGroupAction(action)
                    }
                }
            }
        }
    }
    
    private var dateString: String {
        Date().formatted(.dateTime.year().month().day())
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
    
    private func handlePasswordEntered(_ password: String) {
        switch passwordAction {
        case .export:
            prepareExport(password: password)
        case .import:
            if let url = pendingImportURL {
                importAccounts(from: url, password: password)
            }
        }
    }
    
    private func prepareExport(password: String) {
        do {
            let activeAccounts = accounts.filter { !$0.isDeleted }
            
            // Obtener PINs de grupos desbloqueados desde AppState
            var groupPINs: [UUID: String] = [:]
            for group in groups where group.requiresPIN && groupService.hasPIN(for: group) {
                if let pin = appState.getPIN(for: group.id) {
                    groupPINs[group.id] = pin
                }
            }
            
            let data = try ExportImportService.shared.exportAccountsToData(
                activeAccounts,
                groups: Array(groups),
                password: password,
                groupPINs: groupPINs,
                deviceName: UIDevice.current.name
            )
            exportDocument = BackupDocument(data: data)
            showingExportPicker = true
        } catch {
            alertMessage = "Error al preparar export: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        exportDocument = nil
        
        switch result {
        case .success(let url):
            alertMessage = "Backup guardado correctamente en:\n\(url.lastPathComponent)"
            showingAlert = true
        case .failure(let error):
            // El usuario canceló o hubo error
            if (error as NSError).code != NSUserCancelledError {
                alertMessage = "Error al guardar: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingImportURL = url
            passwordAction = .import
            showingPasswordPrompt = true
            
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                alertMessage = "Error al seleccionar archivo: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func importAccounts(from url: URL, password: String) {
        do {
            // Obtener el grupo por defecto para cuentas importadas sin grupo
            let defaultGroupId = groups.first?.id
            
            let result = try ExportImportService.shared.importAccounts(
                from: url,
                password: password,
                existingAccounts: accounts,
                existingGroups: Array(groups),
                context: modelContext,
                defaultGroupId: defaultGroupId
            )
            
            pendingImportURL = nil
            
            // Si hay grupos protegidos pendientes, iniciar flujo de PINs
            if result.hasProtectedGroups {
                baseImportResult = result
                protectedGroupsToImport = result.protectedGroupsPending
                currentProtectedGroupIndex = 0
                protectedImportStats = (0, 0)
                showingProtectedGroupPIN = true
            } else {
                alertMessage = "Restauración completada:\n\(result.description)"
                showingAlert = true
            }
        } catch {
            alertMessage = "Error al restaurar: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // MARK: - Protected Group Import
    
    private func handleProtectedGroupAction(_ action: ProtectedGroupImportAction) {
        showingProtectedGroupPIN = false
        
        switch action {
        case .imported(let imported, let skipped):
            protectedImportStats.imported += imported
            protectedImportStats.skipped += skipped
            moveToNextProtectedGroup()
            
        case .skipped(let accountCount):
            protectedImportStats.skipped += accountCount
            moveToNextProtectedGroup()
            
        case .cancelled:
            // Marcar todos los restantes como omitidos
            for i in currentProtectedGroupIndex..<protectedGroupsToImport.count {
                protectedImportStats.skipped += protectedGroupsToImport[i].accountCount
            }
            finishProtectedImport()
        }
    }
    
    private func moveToNextProtectedGroup() {
        currentProtectedGroupIndex += 1
        
        if currentProtectedGroupIndex < protectedGroupsToImport.count {
            // Pequeño delay para que el sheet se cierre antes de abrir el siguiente
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingProtectedGroupPIN = true
            }
        } else {
            finishProtectedImport()
        }
    }
    
    private func finishProtectedImport() {
        guard var result = baseImportResult else { return }
        
        result.protectedAccountsImported = protectedImportStats.imported
        result.protectedAccountsSkipped = protectedImportStats.skipped
        result.protectedGroupsPending = []
        
        // Limpiar estado
        baseImportResult = nil
        protectedGroupsToImport = []
        currentProtectedGroupIndex = 0
        protectedImportStats = (0, 0)
        
        alertMessage = "Restauración completada:\n\(result.description)"
        showingAlert = true
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .modelContainer(for: OTPAccount.self, inMemory: true)
}
