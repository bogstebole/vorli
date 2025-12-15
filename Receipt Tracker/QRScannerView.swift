//
//  QRScannerView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    
    @State private var isAuthorized = false
    @State private var showAuthAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isAuthorized {
                    QRScannerCameraView(onScan: { url in
                        onScan(url)
                        dismiss()
                    })
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("Camera Access Required")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                        
                        Text("To scan QR codes, please grant camera access in Settings")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color.blue.gradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await checkCameraAuthorization()
        }
    }
    
    private func checkCameraAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }
}

// MARK: - Camera View

struct QRScannerCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = onScan
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Camera View Controller

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession,
              let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                failed()
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                failed()
                return
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            
            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }
            
            // Add scanning reticle overlay
            addScanningReticle()
            
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        } catch {
            failed()
        }
    }
    
    private func addScanningReticle() {
        let reticleSize: CGFloat = 250
        let reticleView = UIView()
        reticleView.translatesAutoresizingMaskIntoConstraints = false
        reticleView.layer.borderColor = UIColor.systemBlue.cgColor
        reticleView.layer.borderWidth = 3
        reticleView.layer.cornerRadius = 20
        
        view.addSubview(reticleView)
        
        NSLayoutConstraint.activate([
            reticleView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reticleView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reticleView.widthAnchor.constraint(equalToConstant: reticleSize),
            reticleView.heightAnchor.constraint(equalToConstant: reticleSize)
        ])
        
        // Add corner indicators
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        
        let corners: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = [
            (0, 0, cornerLength, cornerWidth), // Top-left horizontal
            (0, 0, cornerWidth, cornerLength), // Top-left vertical
            (reticleSize - cornerLength, 0, cornerLength, cornerWidth), // Top-right horizontal
            (reticleSize - cornerWidth, 0, cornerWidth, cornerLength), // Top-right vertical
            (0, reticleSize - cornerWidth, cornerLength, cornerWidth), // Bottom-left horizontal
            (0, reticleSize - cornerLength, cornerWidth, cornerLength), // Bottom-left vertical
            (reticleSize - cornerLength, reticleSize - cornerWidth, cornerLength, cornerWidth), // Bottom-right horizontal
            (reticleSize - cornerWidth, reticleSize - cornerLength, cornerWidth, cornerLength) // Bottom-right vertical
        ]
        
        for corner in corners {
            let cornerView = UIView(frame: CGRect(x: corner.x, y: corner.y, width: corner.width, height: corner.height))
            cornerView.backgroundColor = .systemBlue
            cornerView.layer.cornerRadius = 2
            reticleView.addSubview(cornerView)
        }
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Align QR code within frame"
        instructionLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.clipsToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(instructionLabel)
        
        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: reticleView.bottomAnchor, constant: 30),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40),
            instructionLabel.widthAnchor.constraint(equalToConstant: 260)
        ])
    }
    
    private func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning QR codes.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession?.stopRunning()
        
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScan?(stringValue)
        }
    }
}

#Preview {
    QRScannerView { url in
        print("Scanned URL: \(url)")
    }
}
