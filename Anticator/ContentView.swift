//
//  ContentView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI
import SwiftData

// MARK: - App Screen State
private enum AppScreen {
    case onboarding
    case locked
    case unlocked
}

// MARK: - Content View
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var authViewModel = AuthenticationViewModel()
    
    private var currentScreen: AppScreen {
        if !appState.hasCompletedOnboarding {
            return .onboarding
        } else if appState.shouldRequireAuthentication && !appState.isUnlocked {
            return .locked
        } else {
            return .unlocked
        }
    }
    
    private var showPrivacyOverlay: Bool {
        appState.isObscured && appState.isUnlocked && appState.hasCompletedOnboarding
    }
    
    var body: some View {
        ZStack {
            screenView
            
            if showPrivacyOverlay {
                PrivacyOverlayView()
                    .transition(.opacity.animation(.easeOut(duration: 0.1)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentScreen)
    }
    
    @ViewBuilder
    private var screenView: some View {
        switch currentScreen {
        case .onboarding:
            SecurityOnboardingView()
                .transition(.opacity)
        case .locked:
            LockScreenView(viewModel: authViewModel)
                .transition(.opacity)
        case .unlocked:
            MainTabView()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.02)),
                    removal: .opacity
                ))
        }
    }
}

// MARK: - Privacy Overlay
struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            backgroundLayers
            brandingContent
        }
        .ignoresSafeArea()
    }
    
    private var backgroundLayers: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.12).opacity(0.7),
                    Color(red: 0.08, green: 0.09, blue: 0.15).opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var brandingContent: some View {
        VStack(spacing: 16) {
            lockIcon
            
            Text(Constants.App.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.8))
        }
    }
    
    private var lockIcon: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 50, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [.accentColor, .accentColor.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
            }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \OTPGroup.order) private var groups: [OTPGroup]
    
    private let groupService = GroupService.shared
    
    private var needsGroupSelection: Bool {
        guard let selectedId = appState.selectedGroupId else { return true }
        return !groups.contains { $0.id == selectedId }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        tabContent(selection: $state.selectedGroupId)
            .onChange(of: needsGroupSelection, initial: true) { _, needsSelection in
                if needsSelection, let firstGroup = groups.first {
                    appState.selectedGroupId = firstGroup.id
                }
            }
    }
    
    @ViewBuilder
    private func tabContent(selection: Binding<UUID?>) -> some View {
        if groups.isEmpty {
            ProgressView()
        } else {
            TabView(selection: selection) {
                ForEach(groups) { group in
                    Tab(tabName(for: group), systemImage: group.iconName, value: group.id) {
                        OTPListView(group: group)
                    }
                }
            }
            .tint(.accentColor)
        }
    }
    
    private func tabName(for group: OTPGroup) -> String {
        // Solo mostrar indicador si el grupo tiene PIN configurado
        guard group.requiresPIN && groupService.hasPIN(for: group) else {
            return group.name
        }
        
        let isUnlocked = appState.isGroupUnlocked(group.id)
        let indicator = isUnlocked ? "🟢" : "🔒"
        return "\(group.name) \(indicator)"
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [OTPAccount.self, OTPGroup.self], inMemory: true)
}
