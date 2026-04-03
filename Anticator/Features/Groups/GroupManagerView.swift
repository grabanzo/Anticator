//
//  GroupManagerView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData

struct GroupManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \OTPGroup.order) private var groups: [OTPGroup]
    @Query private var allAccounts: [OTPAccount]
    
    @State private var showingAddGroup = false
    @State private var editingGroup: OTPGroup?
    @State private var isEditing = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    GroupRow(group: group, accountCount: accountCount(for: group)) {
                        editingGroup = group
                    }
                }
                .onMove(perform: moveGroups)
                .onDelete(perform: deleteGroups)
            }
            .navigationTitle("Grupos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "OK" : "Editar") {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                    .disabled(groups.count <= 1)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .sheet(isPresented: $showingAddGroup) {
                GroupEditorView(mode: .create)
            }
            .sheet(item: $editingGroup) { group in
                GroupEditorView(mode: .edit(group))
            }
            .alert("No se puede eliminar", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
        }
    }
    
    private func accountCount(for group: OTPGroup) -> Int {
        allAccounts.filter { $0.groupId == group.id && $0.deletedAt == nil }.count
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var mutableGroups = groups
        mutableGroups.move(fromOffsets: source, toOffset: destination)
        
        for (index, group) in mutableGroups.enumerated() {
            group.order = index
        }
        
        try? modelContext.save()
    }
    
    private func deleteGroups(at offsets: IndexSet) {
        // No permitir eliminar si solo queda un grupo
        guard groups.count > 1 else {
            deleteErrorMessage = String(localized: "Debe existir al menos un grupo.")
            showingDeleteError = true
            return
        }
        
        for index in offsets {
            let group = groups[index]
            let count = accountCount(for: group)
            
            if count > 0 {
                deleteErrorMessage = String(localized: "group_has_codes \(group.name) \(count)")
                showingDeleteError = true
                return
            }
            
            // Delete requiere limpiar PIN del Keychain - usar Service
            try? GroupService.shared.deleteGroup(group, in: modelContext)
        }
    }
}

// MARK: - Group Row
struct GroupRow: View {
    let group: OTPGroup
    let accountCount: Int
    let onEdit: () -> Void
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Icono
                ZStack {
                    Circle()
                        .fill(group.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: group.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(group.color)
                }
                
                // Nombre y detalles
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text(String(localized: "codes_count \(accountCount)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if group.requiresPIN {
                            Label("PIN", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Group Editor View
struct GroupEditorView: View {
    enum Mode {
        case create
        case edit(OTPGroup)
    }
    
    let mode: Mode
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \OTPGroup.order) private var existingGroups: [OTPGroup]
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColorHex: String = "007AFF"
    @State private var requiresPIN: Bool = false
    @State private var hasPINConfigured: Bool = false  // Si ya tiene PIN guardado
    @State private var wantsToChangePIN: Bool = false  // Si quiere cambiar el PIN
    @State private var currentPIN: String = ""  // PIN actual (para verificar)
    @State private var pin: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinStep: Int = 0  // 0: verificar actual, 1: nuevo PIN, 2: confirmar nuevo
    @State private var error: String?
    @State private var newPINReady: String? = nil  // PIN listo para guardar
    @State private var pinVerifiedForDisable: Bool = false  // Si se verificó PIN para desactivar
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    
    private let groupService = GroupService.shared
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var editingGroup: OTPGroup? {
        if case .edit(let group) = mode { return group }
        return nil
    }
    
    private var canSave: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        
        // Si quiere desactivar PIN existente, necesita haberlo verificado
        if !requiresPIN && hasPINConfigured {
            return nameValid && pinVerifiedForDisable
        }
        
        // Si no requiere PIN y no tenía PIN configurado, solo validar nombre
        if !requiresPIN { return nameValid }
        
        // Si ya tiene PIN y no quiere cambiarlo, OK
        if hasPINConfigured && !wantsToChangePIN { return nameValid }
        
        // Si está configurando nuevo PIN, necesita tenerlo listo
        return nameValid && newPINReady != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Nombre
                Section {
                    TextField("Nombre del grupo", text: $name)
                } header: {
                    Text("Nombre")
                }
                
                // Icono
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(OTPGroup.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex)!.opacity(0.2) : Color.secondary.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColorHex)! : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icono")
                }
                
                // Color
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(OTPGroup.availableColors, id: \.hex) { color in
                            Button {
                                selectedColorHex = color.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: color.hex)!)
                                        .frame(width: 40, height: 40)
                                    
                                    if selectedColorHex == color.hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }
                
                // PIN
                Section {
                    Toggle("Proteger con PIN", isOn: $requiresPIN)
                        .onChange(of: requiresPIN) { _, newValue in
                            if newValue && !hasPINConfigured {
                                // Activar PIN nuevo (o reactivar después de desactivar)
                                wantsToChangePIN = true
                                pinStep = 1
                                pin = ""
                                confirmPIN = ""
                                newPINReady = nil  // Resetear cualquier PIN pendiente
                                error = nil
                            } else if newValue && hasPINConfigured {
                                // Reactivando PIN existente - resetear estado de desactivación
                                pinVerifiedForDisable = false
                                currentPIN = ""
                                error = nil
                            } else if !newValue && hasPINConfigured {
                                // Desactivar PIN existente - pedir verificación
                                pinStep = 0
                                currentPIN = ""
                                pinVerifiedForDisable = false
                                error = nil
                            } else if !newValue && !hasPINConfigured {
                                // Desactivar PIN nuevo (aún no guardado)
                                newPINReady = nil
                                wantsToChangePIN = false
                                pin = ""
                                confirmPIN = ""
                                error = nil
                            }
                        }
                    
                    // Si tiene PIN y quiere quitarlo, pedir verificación
                    if !requiresPIN && hasPINConfigured {
                        VStack(spacing: 16) {
                            if pinVerifiedForDisable {
                                // PIN verificado correctamente
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.green)
                                
                                Text("PIN verificado. Guarda para confirmar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Introduce el PIN actual para desactivar")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PINDots(count: currentPIN.count)
                                
                                PINKeypad(pin: $currentPIN)
                                    .padding(.horizontal, 20)
                                
                                if let error = error {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .onChange(of: currentPIN) { _, newValue in
                            if newValue.count == 4 {
                                verifyCurrentPINToDisable()
                            }
                        }
                    }
                    
                    // Si tiene PIN configurado y no está intentando quitarlo ni tiene nuevo PIN listo
                    if requiresPIN && hasPINConfigured && !wantsToChangePIN && newPINReady == nil {
                        Button {
                            wantsToChangePIN = true
                            pinStep = 0
                            currentPIN = ""
                            pin = ""
                            confirmPIN = ""
                        } label: {
                            Label("Cambiar PIN", systemImage: "key.fill")
                        }
                    }
                    
                    // Si hay nuevo PIN listo, mostrar confirmación visual
                    if requiresPIN && newPINReady != nil {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.green)
                            
                            Text("Nuevo PIN configurado")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                // Permitir cambiar de nuevo
                                newPINReady = nil
                                wantsToChangePIN = true
                                pinStep = hasPINConfigured ? 0 : 1
                                currentPIN = ""
                                pin = ""
                                confirmPIN = ""
                            } label: {
                                Text("Cambiar")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    
                    // Si quiere cambiar o crear PIN (y no está ya listo)
                    if requiresPIN && wantsToChangePIN && newPINReady == nil {
                        VStack(spacing: 16) {
                            if hasPINConfigured && pinStep == 0 {
                                // Primero verificar PIN actual
                                Text("Introduce el PIN actual")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PINDots(count: currentPIN.count)
                                
                                PINKeypad(pin: $currentPIN)
                                    .padding(.horizontal, 20)
                            } else if pinStep == 1 {
                                // Introducir nuevo PIN
                                Text("Introduce el nuevo PIN")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PINDots(count: pin.count)
                                
                                PINKeypad(pin: $pin)
                                    .padding(.horizontal, 20)
                            } else if pinStep == 2 {
                                // Confirmar nuevo PIN
                                Text("Confirma el nuevo PIN")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                PINDots(count: confirmPIN.count)
                                
                                PINKeypad(pin: $confirmPIN)
                                    .padding(.horizontal, 20)
                            }
                            
                            if let error = error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 16)
                        .onChange(of: currentPIN) { _, newValue in
                            if newValue.count == 4 && pinStep == 0 {
                                verifyCurrentPINToChange()
                            }
                        }
                        .onChange(of: pin) { _, newValue in
                            if newValue.count == 4 && pinStep == 1 {
                                pinStep = 2
                                error = nil
                            }
                        }
                        .onChange(of: confirmPIN) { _, newValue in
                            if newValue.count == 4 {
                                if pin != confirmPIN {
                                    error = String(localized: "Los PINs no coinciden")
                                    confirmPIN = ""
                                } else {
                                    // PIN confirmado correctamente - guardarlo para cuando se guarde el grupo
                                    error = nil
                                    newPINReady = pin
                                    wantsToChangePIN = false
                                    
                                    // Haptic feedback
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Seguridad")
                } footer: {
                    if requiresPIN && newPINReady != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nuevo PIN configurado ✓ Guarda para confirmar.")
                                .foregroundStyle(.green)
                            Text(String(localized: "⚠️ Si olvidas el PIN, no podrás recuperar el acceso. Deberás eliminar el grupo y sus cuentas."))
                                .foregroundStyle(.orange)
                        }
                    } else if requiresPIN && !wantsToChangePIN && hasPINConfigured {
                        Text("PIN configurado ✓")
                            .foregroundStyle(.green)
                    } else if requiresPIN && wantsToChangePIN {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Se te pedirá este PIN cada vez que accedas al grupo.")
                            Text(String(localized: "⚠️ Si olvidas el PIN, no podrás recuperar el acceso."))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar grupo" : "Nuevo grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveGroup()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let group = editingGroup {
                    name = group.name
                    selectedIcon = group.iconName
                    selectedColorHex = group.colorHex
                    requiresPIN = group.requiresPIN
                    // Verificar si ya tiene PIN guardado - usar Service
                    if group.requiresPIN {
                        hasPINConfigured = groupService.hasPIN(for: group)
                    }
                }
            }
            .alert("Error al guardar", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
        }
    }
    
    private func verifyCurrentPINToChange() {
        guard let group = editingGroup else { return }
        
        if groupService.verifyPIN(currentPIN, for: group) {
            // PIN correcto, permitir cambiar
            pinStep = 1
            error = nil
        } else {
            error = String(localized: "PIN incorrecto")
            currentPIN = ""
        }
    }
    
    private func verifyCurrentPINToDisable() {
        guard let group = editingGroup else { return }
        
        if groupService.verifyPIN(currentPIN, for: group) {
            // PIN correcto, permitir desactivar
            pinVerifiedForDisable = true
            error = nil
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            error = String(localized: "PIN incorrecto")
            currentPIN = ""
        }
    }
    
    private func saveGroup() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        do {
            if let group = editingGroup {
                // Editar grupo existente
                
                // Primero intentar guardar/eliminar PIN (puede fallar)
                if let pinToSave = newPINReady {
                    try groupService.savePIN(pinToSave, for: group)
                }
                
                if !requiresPIN && pinVerifiedForDisable {
                    try groupService.removePIN(for: group)
                }
                
                // Solo si el PIN se guardó correctamente, actualizar el modelo
                group.name = trimmedName
                group.iconName = selectedIcon
                group.colorHex = selectedColorHex
                group.requiresPIN = requiresPIN
                
            } else {
                // Crear nuevo grupo
                let newGroup = OTPGroup(
                    name: trimmedName,
                    iconName: selectedIcon,
                    colorHex: selectedColorHex,
                    order: existingGroups.count,
                    requiresPIN: requiresPIN
                )
                
                // Si hay PIN, guardarlo ANTES de insertar el grupo
                if let pinToSave = newPINReady {
                    try groupService.savePIN(pinToSave, for: newGroup)
                }
                
                modelContext.insert(newGroup)
            }
            
            try modelContext.save()
            dismiss()
            
        } catch {
            saveErrorMessage = "No se pudo guardar: \(error.localizedDescription)"
            showingSaveError = true
        }
    }
}

#Preview {
    GroupManagerView()
        .modelContainer(for: OTPGroup.self, inMemory: true)
        .environment(AppState())
}

