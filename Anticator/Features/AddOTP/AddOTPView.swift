//
//  AddOTPView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftUI

struct AddOTPView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    let groupId: UUID?
    
    init(groupId: UUID? = nil) {
        self.groupId = groupId
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selector de método
                Picker("Método", selection: $selectedTab) {
                    Label("Escanear QR", systemImage: "qrcode.viewfinder")
                        .tag(0)
                    Label("Manual", systemImage: "keyboard")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Contenido según selección
                TabView(selection: $selectedTab) {
                    ScannerView(groupId: groupId, onScan: handleScan)
                        .tag(0)
                    
                    ManualEntryView(groupId: groupId, onSave: handleManualEntry)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Añadir código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleScan(_ uri: String) {
        dismiss()
    }
    
    private func handleManualEntry() {
        dismiss()
    }
}

#Preview {
    AddOTPView()
}

