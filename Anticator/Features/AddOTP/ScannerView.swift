//
//  ScannerView.swift
//  Anticator
//
//  Created by Marcos Riosalido Vilagrasa on 28/12/25.
//

import SwiftData
import SwiftUI
@preconcurrency import AVFoundation

struct ScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let groupId: UUID?
    let onScan: (String) -> Void
    
    init(groupId: UUID? = nil, onScan: @escaping (String) -> Void) {
        self.groupId = groupId
        self.onScan = onScan
    }
    
    @State private var isScanning = true
    @State private var scannedCode: String?
    @State private var error: String?
    @State private var showingError = false
    @State private var cameraPermissionDenied = false
    
    var body: some View {
        ZStack {
            if cameraPermissionDenied {
                cameraPermissionView
            } else {
                CameraPreviewView(
                    isScanning: $isScanning,
                    onCodeScanned: handleScannedCode
                )
                .ignoresSafeArea()
                
                // Overlay con guía
                scannerOverlay
            }
        }
        .task {
            await checkCameraPermission()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                isScanning = true
                error = nil
            }
        } message: {
            Text(error ?? "Error desconocido")
        }
    }
    
    private var scannerOverlay: some View {
        VStack {
            Spacer()
            
            // Marco de escaneo
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10]))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 250, height: 250)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.001)) // Para capturar el área
                )
            
            Spacer()
            
            // Instrucciones
            VStack(spacing: 8) {
                Text("Escanea el código QR")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Apunta la cámara al código QR de configuración 2FA")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.bottom, 40)
        }
        .padding()
    }
    
    private var cameraPermissionView: some View {
        ContentUnavailableView {
            Label("Cámara no disponible", systemImage: "camera.fill")
        } description: {
            Text("Anticator necesita acceso a la cámara para escanear códigos QR. Puedes habilitarlo en Ajustes.")
        } actions: {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func checkCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionDenied = !granted
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }
    
    private func handleScannedCode(_ code: String) {
        isScanning = false
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        do {
            // Parsear URI
            let parsed = try ParsedOTPURI.parse(from: code)
            
            // Create requiere guardar en Keychain - usar Service
            _ = try OTPAccountService.shared.createAccount(
                in: modelContext,
                from: parsed,
                groupId: groupId
            )
            
            // Éxito
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
            
            onScan(code)
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    @Binding var isScanning: Bool
    let onCodeScanned: (String) -> Void
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if isScanning {
            uiView.startScanning()
        } else {
            uiView.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    class Coordinator: NSObject, CameraPreviewDelegate {
        let onCodeScanned: (String) -> Void
        
        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func didScanCode(_ code: String) {
            onCodeScanned(code)
        }
    }
}

protocol CameraPreviewDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class CameraPreviewUIView: UIView {
    weak var delegate: CameraPreviewDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var hasProcessedCode = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    private static let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    func startScanning() {
        if !isConfigured {
            configureSession()
        }
        
        hasProcessedCode = false
        
        let session = captureSession
        Self.sessionQueue.async {
            session?.startRunning()
        }
    }
    
    func stopScanning() {
        let session = captureSession
        Self.sessionQueue.async {
            session?.stopRunning()
        }
    }
    
    private func configureSession() {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.previewLayer = previewLayer
        self.isConfigured = true
    }
}

extension CameraPreviewUIView: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue,
              code.hasPrefix("otpauth://") else {
            return
        }
        
        DispatchQueue.main.async {
            guard !self.hasProcessedCode else { return }
            self.hasProcessedCode = true
            self.stopScanning()
            self.delegate?.didScanCode(code)
        }
    }
}

#Preview {
    ScannerView { code in
        print("Scanned: \(code)")
    }
}

