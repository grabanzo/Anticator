//
//  AnticatorApp.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData

@main
struct AnticatorApp: App {
    let modelContainer: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()

    init() {
        do {
            let schema = Schema(
                [OTPAccount.self, OTPGroup.self]
            )
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Inicialización de datos antes de asignar el container
            AppBootstrapService.initialize(context: container.mainContext)
            
            modelContainer = container
        } catch {
            fatalError("No se pudo inicializar ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(modelContainer)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
//                .onOpenURL { url in
//                    handleIncomingFile(url)
//                }
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        // No hacer nada si el onboarding no se ha completado
        guard appState.hasCompletedOnboarding else { return }
        
        switch newPhase {
        case .background:
            // Bloquear al ir a background si está habilitada la autenticación
            if appState.shouldRequireAuthentication {
                appState.isUnlocked = false
            }
            // Bloquear todos los grupos protegidos
            appState.lockAllGroups()
        case .inactive:
            // Mostrar blur mientras está en el app switcher
            appState.isObscured = true
        case .active:
            // Quitar blur al volver
            appState.isObscured = false
            // Disparar autenticación automática si está bloqueada
            if appState.shouldRequireAuthentication && !appState.isUnlocked {
                appState.authTrigger += 1
            }
        @unknown default:
            break
        }
    }

    private func handleIncomingFile(_ url: URL) {
        guard url.pathExtension.lowercased() == Constants.Backup.fileExtension else { return }
        appState.pendingImportURL = url
        appState.showImportSheet = true
    }

}
