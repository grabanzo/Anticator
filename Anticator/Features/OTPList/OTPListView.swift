//
//  OTPListView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case manual = "Manual"
    case nameAsc = "Nombre A-Z"
    case nameDesc = "Nombre Z-A"
    case dateNewest = "Más recientes"
    case dateOldest = "Más antiguos"
    
    var icon: String {
        switch self {
        case .manual: return "hand.draw"
        case .nameAsc: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .dateNewest: return "calendar.badge.clock"
        case .dateOldest: return "calendar"
        }
    }
}

struct OTPListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    let group: OTPGroup
    
    @Query(sort: \OTPAccount.order) private var allAccounts: [OTPAccount]
    @Query private var allGroups: [OTPGroup]
    
    @State private var viewModel = OTPListViewModel()
    @State private var searchText = ""
    @State private var showingSettingsSheet = false
    @State private var showingAddSheet = false  // Solo para el empty state
    @State private var selectedAccount: OTPAccount?
    @State private var sortOption: SortOption = .manual
    @State private var isEditing = false
    @State private var showingPINEntry = false
    @State private var accountToDelete: OTPAccount?
    @State private var accountToExport: OTPAccount?
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteGroupConfirmation = false
    
    private let groupService = GroupService.shared
    
    // Cuentas del grupo actual
    private var accounts: [OTPAccount] {
        allAccounts.filter { $0.deletedAt == nil && $0.groupId == group.id }
    }
    
    var sortedAccounts: [OTPAccount] {
        switch sortOption {
        case .manual:
            return accounts.sorted { $0.order < $1.order }
        case .nameAsc:
            return accounts.sorted { $0.issuer.localizedCaseInsensitiveCompare($1.issuer) == .orderedAscending }
        case .nameDesc:
            return accounts.sorted { $0.issuer.localizedCaseInsensitiveCompare($1.issuer) == .orderedDescending }
        case .dateNewest:
            return accounts.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return accounts.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    var filteredAccounts: [OTPAccount] {
        let sorted = sortedAccounts
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { account in
            account.issuer.localizedCaseInsensitiveContains(searchText) ||
            account.accountName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Verifica si el grupo necesita PIN y no está desbloqueado
    // También verifica que realmente exista un PIN en Keychain (evita bloqueo permanente por desincronización)
    private var needsPIN: Bool {
        group.requiresPIN && !appState.isGroupUnlocked(group.id) && groupService.hasPIN(for: group)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if needsPIN {
                    lockedGroupView
                } else if accounts.isEmpty {
                    emptyStateView
                } else {
                    accountsList
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Buscar cuenta")
            .toolbar {
                // Editar (izquierda) - estilo iOS estándar
                if !needsPIN && !accounts.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                if !isEditing {
                                    // Al entrar en modo edición, cambiar a manual para permitir reordenar
                                    sortOption = .manual
                                }
                                isEditing.toggle()
                            }
                        } label: {
                            Text(isEditing ? "OK" : "Editar")
                        }
                    }
                }
                
                // Ordenación y Settings (derecha)
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // Ordenación
                        if !needsPIN {
                            Menu {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Button {
                                        withAnimation {
                                            sortOption = option
                                            if option != .manual {
                                                isEditing = false
                                            }
                                        }
                                    } label: {
                                        Label(option.rawValue, systemImage: option.icon)
                                        if sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        
                        // Settings
                        Button {
                            showingSettingsSheet = true
                        } label: {
                            Image(systemName: "person.circle")
                                .font(.system(size: 22))
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .sheet(isPresented: $showingAddSheet) {
                AddOTPView(groupId: group.id)
            }
            .sheet(item: $selectedAccount) { account in
                OTPDetailView(account: account)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsSheet()
            }
            .sheet(item: $accountToExport) { account in
                ExportKeyView(account: account)
            }
            .sheet(isPresented: $showingPINEntry) {
                GroupPINEntryView(group: group) { success, pin in
                    if success {
                        appState.unlockGroup(group.id, withPIN: pin)
                    }
                }
            }
            .alert(
                "¿Eliminar cuenta?",
                isPresented: $showingDeleteConfirmation,
                presenting: accountToDelete
            ) { account in
                Button("Cancelar", role: .cancel) {
                    accountToDelete = nil
                }
                Button("Eliminar", role: .destructive) {
                    deleteAccount(account)
                }
            } message: { account in
                Text(String(localized: "Se eliminará \"\(account.issuer)\" y su código de verificación. Esta acción no se puede deshacer."))
            }
            .alert(
                String(localized: "¿Eliminar grupo \"\(group.name)\"?"),
                isPresented: $showingDeleteGroupConfirmation
            ) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar grupo", role: .destructive) {
                    deleteLockedGroup()
                }
            } message: {
                Text(String(localized: "Se eliminarán todas las cuentas del grupo. Esta acción no se puede deshacer.\n\nSi olvidaste el PIN, no hay forma de recuperar el acceso."))
            }
            .onAppear {
                viewModel.startTimer()
                // Verificar si el grupo necesita PIN (y realmente tiene uno configurado)
                if needsPIN {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        showingPINEntry = true
                    }
                }
            }
            .onDisappear {
                viewModel.stopTimer()
            }
        }
    }
    
    // MARK: - Locked Group View
    
    private var lockedGroupView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(group.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(group.color)
            }
            
            VStack(spacing: 12) {
                Text("Grupo protegido")
                    .font(.title3.bold())
                
                Text("Este grupo requiere PIN para acceder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 14) {
                Button {
                    showingPINEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 16))
                        Text("Desbloquear")
                            .font(.headline)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(group.color)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                
                if canDeleteGroup {
                    Button {
                        showingDeleteGroupConfirmation = true
                    } label: {
                        Text(String(localized: "¿Olvidaste el PIN?"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [group.color.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Image(systemName: group.iconName)
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [group.color, group.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "Sin códigos en \(group.name)"))
                    .font(.title3.bold())
                
                Text("Añade tu primer código de autenticación\na este grupo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
            Spacer()
            addButton
        }
        .padding()
    }
    
    // MARK: - Accounts List
    
    private var accountsList: some View {
        List {
            ForEach(filteredAccounts) { account in
                OTPRowView(
                    account: account,
                    currentTime: viewModel.currentTime
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    copyCode(for: account)
                }
                .contextMenu {
                    Button {
                        copyCode(for: account)
                    } label: {
                        Label("Copiar código", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        selectedAccount = account
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    
                    Button {
                        accountToExport = account
                    } label: {
                        Label("Exportar clave", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        accountToDelete = account
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        accountToDelete = account
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        selectedAccount = account
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onMove(perform: moveAccounts)
            .onDelete(perform: confirmDeleteAccounts)                
        }
        .listStyle(.plain)
        .refreshable {
            viewModel.refresh()
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            addButton
        }
    }
    
    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Constants.UI.fabSize, height: Constants.UI.fabSize)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [group.color, group.color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: group.color.opacity(0.4), radius: 8, y: 4)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func copyCode(for account: OTPAccount) {
        guard let code = viewModel.generateCode(for: account) else { return }
        UIPasteboard.general.string = code
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        viewModel.showCopiedFeedback(for: account.id)
    }
    
    private func deleteAccount(_ account: OTPAccount) {
        try? OTPAccountService.shared.deleteAccount(account, in: modelContext)
    }
    
    private func moveAccounts(from source: IndexSet, to destination: Int) {
        guard sortOption == .manual else { return }
        
        var mutableAccounts = filteredAccounts
        mutableAccounts.move(fromOffsets: source, toOffset: destination)
        
        // Reordenar directamente (operación simple sin side-effects)
        for (index, account) in mutableAccounts.enumerated() {
            account.order = index
            account.updatedAt = Date()
        }
        try? modelContext.save()
    }
    
    private func confirmDeleteAccounts(at offsets: IndexSet) {
        // Obtener la primera cuenta a eliminar y mostrar confirmación
        guard let index = offsets.first else { return }
        accountToDelete = filteredAccounts[index]
        showingDeleteConfirmation = true
    }
    
    private var canDeleteGroup: Bool {
        allGroups.count > 1
    }
    
    private func deleteLockedGroup() {
        guard canDeleteGroup else { return }
        
        // Eliminar todas las cuentas del grupo
        for account in accounts {
            try? OTPAccountService.shared.deleteAccount(account, in: modelContext)
        }
        
        // Eliminar el grupo (incluye limpiar PIN del Keychain)
        try? groupService.deleteGroup(group, in: modelContext)
        
        // Cambiar a otro grupo
        appState.selectedGroupId = nil
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cerrar") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Group PIN Entry View
struct GroupPINEntryView: View {
    let group: OTPGroup
    /// Callback con (success, pin). El PIN se devuelve solo si success=true
    let onComplete: (Bool, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pin = ""
    @State private var error: String?
    @State private var attempts = 0
    @State private var shake = false
    
    private let groupService = GroupService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Icono del grupo
                    ZStack {
                        Circle()
                            .fill(group.color.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: group.iconName)
                            .font(.system(size: 44))
                            .foregroundStyle(group.color)
                    }
                    
                    VStack(spacing: 8) {
                        Text(group.name)
                            .font(.title2.bold())
                        
                        Text("Introduce el PIN para acceder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    PINDots(count: pin.count)
                        .offset(x: shake ? -10 : 0)
                        .animation(.spring(response: 0.1, dampingFraction: 0.3).repeatCount(3), value: shake)
                    
                    if let error = error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    PINKeypad(pin: $pin)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                        .frame(height: 40)
                }
                .padding()
            }
            .navigationTitle("PIN del grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onComplete(false, nil)
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
        if groupService.verifyPIN(pin, for: group) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onComplete(true, pin)  // Devolver el PIN para guardarlo en memoria
            dismiss()
        } else {
            handleWrongPIN()
        }
    }
    
    private func handleWrongPIN() {
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
            error = String(localized: "Demasiados intentos")
            Task {
                try? await Task.sleep(for: .seconds(1))
                onComplete(false, nil)
                dismiss()
            }
        }
    }
}

#Preview {
    let group = OTPGroup(name: "Personal", iconName: "person.fill", colorHex: "007AFF")
    
    let sampleAccounts = [
        OTPAccount(issuer: "Google", accountName: "usuario@gmail.com", secretKeyRef: "preview_1", iconName: "google", groupId: group.id, order: 0),
        OTPAccount(issuer: "GitHub", accountName: "developer", secretKeyRef: "preview_2", iconName: "github", groupId: group.id, order: 1),
        OTPAccount(issuer: "Apple", accountName: "user@icloud.com", secretKeyRef: "preview_3", iconName: "apple", groupId: group.id, order: 2),
        OTPAccount(issuer: "Amazon", accountName: "shopper@email.com", secretKeyRef: "preview_4", iconName: "amazon", groupId: group.id, order: 3),
        OTPAccount(issuer: "Discord", accountName: "gamer#1234", secretKeyRef: "preview_5", iconName: "discord", groupId: group.id, order: 4),
        OTPAccount(issuer: "Discord", accountName: "gamer#1234", secretKeyRef: "preview_6", iconName: "discord", groupId: group.id, order: 5),
        OTPAccount(issuer: "Discord", accountName: "gamer#1234", secretKeyRef: "preview_7", iconName: "discord", groupId: group.id, order: 6),

    ]
    
    return OTPListView(group: group)
        .modelContainer(for: [OTPAccount.self, OTPGroup.self], inMemory: true) { result in
            if case .success(let container) = result {
                let context = container.mainContext
                context.insert(group)
                sampleAccounts.forEach { context.insert($0) }
            }
        }
        .environment(AppState())
}
