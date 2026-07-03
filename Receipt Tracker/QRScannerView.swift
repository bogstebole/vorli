//
//  QRScannerView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import AVFoundation
import PhotosUI

enum ScanMode: String, CaseIterable {
    case qrCode = "QR Kod"
    case receipt = "Račun"
}

extension Notification.Name {
    /// Posted after the QR capture session has fully stopped and released the
    /// camera device.
    static let qrScannerSessionDidStop = Notification.Name("qrScannerSessionDidStop")
}

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    let onReceiptParsed: ((ParsedReceipt) -> Void)?

    @State private var isAuthorized = false
    @State private var showAuthAlert = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var scanMode: ScanMode = .qrCode
    @State private var isProcessing = false
    @State private var showDocScanner = false

    init(onScan: @escaping (String) -> Void, onReceiptParsed: ((ParsedReceipt) -> Void)? = nil) {
        self.onScan = onScan
        self.onReceiptParsed = onReceiptParsed
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isAuthorized {
                    VStack(spacing: 0) {
                        // Segmented Control
                        Picker("Način skeniranja", selection: $scanMode) {
                            ForEach(ScanMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        
                        // Camera view based on mode
                        ZStack {
                            if scanMode == .qrCode {
                                QRScannerCameraView(onScan: { url in
                                    onScan(url)
                                    dismiss()
                                })
                            } else {
                                VStack(spacing: 20) {
                                    Image(systemName: "doc.viewfinder")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                    Text("Skeniraj račun")
                                        .font(.system(.title2, design: .monospaced, weight: .bold))
                                    Text("Postavi račun na ravnu površinu — ivice se prepoznaju automatski.")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    Button { showDocScanner = true } label: {
                                        Label("Otvori skener", systemImage: "camera.viewfinder")
                                            .font(.system(.body, design: .monospaced))
                                            .padding()
                                            .background(Color.blue.gradient)
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Processing overlay
                            if isProcessing {
                                Color.black.opacity(0.7)
                                    .ignoresSafeArea()
                                
                                VStack(spacing: 20) {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(1.5)
                                    
                                    Text("Obrađujem račun...")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        
                        Text("Potreban pristup kameri")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                        
                        Text("Da biste skenirali QR kodove, omogućite pristup kameri u podešavanjima")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        } label: {
                            Text("Otvori podešavanja")
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
            .navigationTitle(scanMode == .qrCode ? "Skeniraj QR kod" : "Skeniraj račun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Otkaži") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Učitaj", systemImage: "photo.on.rectangle")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .alert("Greška", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await checkCameraAuthorization()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if scanMode == .qrCode {
                    await loadAndDecodeQRCode(from: newValue)
                } else {
                    await loadAndProcessReceipt(from: newValue)
                }
            }
        }
        .onChange(of: scanMode) { _, mode in
            guard mode == .receipt, DocumentScannerView.isSupported else { return }
            // Don't present the document scanner immediately: the QR session
            // is still releasing the camera, and the system scanner stalls for
            // seconds waiting on it. The .qrScannerSessionDidStop notification
            // presents it as soon as the camera is free; this is only a
            // fallback in case the QR session was never running.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if scanMode == .receipt && !showDocScanner {
                    showDocScanner = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .qrScannerSessionDidStop)) { _ in
            if scanMode == .receipt && !showDocScanner {
                showDocScanner = true
            }
        }
        .fullScreenCover(isPresented: $showDocScanner) {
            DocumentScannerView(
                onScan: { image in
                    showDocScanner = false
                    handleReceiptCapture(image)
                },
                onCancel: { showDocScanner = false },
                onError: { error in
                    showDocScanner = false
                    errorMessage = "Greška skenera: \(error.localizedDescription)"
                    showError = true
                }
            )
            .ignoresSafeArea()
        }
    }
    
    /// May be called from the photo-capture delegate's background thread, so
    /// all state mutation is funneled onto the main actor.
    private func handleReceiptCapture(_ image: UIImage) {
        debugLog("📷 QRScannerView.handleReceiptCapture called")
        debugLog("📐 Image size: \(image.size)")

        Task { @MainActor in
            isProcessing = true
            do {
                // Use OCR parser to extract receipt data
                let parsedReceipt = try await ReceiptOCRParser.parseReceipt(from: image)

                // Hand the parsed result to the confirmation flow (parse once).
                isProcessing = false
                onReceiptParsed?(parsedReceipt)
                dismiss()
            } catch {
                debugLog("❌ Error in handleReceiptCapture: \(error)")
                isProcessing = false
                errorMessage = "Neuspešna obrada računa: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func loadAndProcessReceipt(from photoItem: PhotosPickerItem?) async {
        debugLog("🖼️ QRScannerView.loadAndProcessReceipt called")
        guard let photoItem = photoItem else { 
            debugLog("⚠️ No photo item provided")
            return 
        }
        
        isProcessing = true
        
        do {
            debugLog("📦 Loading image data from PhotosPickerItem")
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: imageData) else {
                debugLog("❌ Failed to load image data")
                errorMessage = "Neuspešno učitavanje slike"
                showError = true
                isProcessing = false
                return
            }
            
            debugLog("✅ Image loaded successfully, size: \(uiImage.size)")
            handleReceiptCapture(uiImage)
        } catch {
            debugLog("❌ Error loading image: \(error)")
            errorMessage = "Neuspešna obrada slike: \(error.localizedDescription)"
            showError = true
            isProcessing = false
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
    
    private func loadAndDecodeQRCode(from photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }
        
        do {
            guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: imageData),
                  let ciImage = CIImage(image: uiImage) else {
                errorMessage = "Neuspešno učitavanje slike"
                showError = true
                return
            }
            
            // Detect QR codes in the image
            let context = CIContext()
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            
            guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature],
                  let firstFeature = features.first,
                  let qrCodeString = firstFeature.messageString else {
                errorMessage = "Nije pronađen QR kod na odabranoj slici"
                showError = true
                return
            }
            
            // Successfully decoded QR code
            onScan(qrCodeString)
            dismiss()
            
        } catch {
            errorMessage = "Neuspešna obrada slike: \(error.localizedDescription)"
            showError = true
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
    // All session configuration and start/stop happens off the main thread —
    // AVCaptureSession setup takes long enough to cause a visible UI hitch.
    private let sessionQueue = DispatchQueue(label: "qr.scanner.session", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, session.isRunning {
                session.stopRunning()
            }
            // Tell whoever is waiting (the document scanner) that the camera
            // is now free — presenting it before the QR session releases the
            // device makes the system camera stall for seconds on arbitration.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .qrScannerSessionDidStop, object: nil)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        // Preview layer and overlay can attach immediately; frames appear
        // once the session is configured and started on the session queue.
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        addScanningReticle()

        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                DispatchQueue.main.async { self.failed() }
                return
            }

            session.beginConfiguration()

            guard session.canAddInput(videoInput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.failed() }
                return
            }
            session.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard session.canAddOutput(metadataOutput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.failed() }
                return
            }
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [.qr]

            session.commitConfiguration()

            // The delegate is main-actor isolated, so hook it up on the main
            // thread, then start the session (ordered via the session queue so
            // no scan can arrive before the delegate is set).
            DispatchQueue.main.async {
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                self.sessionQueue.async {
                    session.startRunning()
                }
            }
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
        view.accessibilityViewIsModal = true
        
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
        instructionLabel.text = "Poravnajte QR kod unutar okvira"
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
        let ac = UIAlertController(title: "Skeniranje nije podržano", message: "Vaš uređaj ne podržava skeniranje QR kodova.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }

        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScan?(stringValue)
        }
    }
}

// MARK: - Receipt Scanner Camera View

struct ReceiptScannerCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> ReceiptScannerViewController {
        let controller = ReceiptScannerViewController()
        controller.onCapture = onCapture
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ReceiptScannerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Receipt Scanner View Controller

class ReceiptScannerViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var captureButton: UIButton?
    // All session configuration and start/stop happens off the main thread —
    // AVCaptureSession setup takes long enough to cause a visible UI hitch.
    private let sessionQueue = DispatchQueue(label: "receipt.scanner.session", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupCaptureButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, session.isRunning {
                session.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        addReceiptFrameOverlay()

        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                debugLog("Error setting up receipt camera: no device/input")
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .photo

            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            self.photoOutput = output

            session.commitConfiguration()
            session.startRunning()
        }
    }
    
    private func addReceiptFrameOverlay() {
        // Add dimmed overlay with transparent rectangle for receipt
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        
        let dimView = UIView(frame: view.bounds)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Create transparent rectangle for receipt
        let receiptWidth: CGFloat = view.bounds.width * 0.85
        let receiptHeight: CGFloat = receiptWidth * 1.4 // Typical receipt aspect ratio
        let receiptX = (view.bounds.width - receiptWidth) / 2
        let receiptY = (view.bounds.height - receiptHeight) / 2
        
        let receiptRect = CGRect(x: receiptX, y: receiptY, width: receiptWidth, height: receiptHeight)
        
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: dimView.bounds)
        path.append(UIBezierPath(roundedRect: receiptRect, cornerRadius: 12).reversing())
        maskLayer.path = path.cgPath
        dimView.layer.mask = maskLayer
        
        overlayView.addSubview(dimView)
        
        // Add border around receipt area
        let borderView = UIView(frame: receiptRect)
        borderView.layer.borderColor = UIColor.systemBlue.cgColor
        borderView.layer.borderWidth = 3
        borderView.layer.cornerRadius = 12
        borderView.isUserInteractionEnabled = false
        
        overlayView.addSubview(borderView)
        
        // Add corner indicators
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 4
        
        let corners: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = [
            (0, 0, cornerLength, cornerWidth),
            (0, 0, cornerWidth, cornerLength),
            (receiptWidth - cornerLength, 0, cornerLength, cornerWidth),
            (receiptWidth - cornerWidth, 0, cornerWidth, cornerLength),
            (0, receiptHeight - cornerWidth, cornerLength, cornerWidth),
            (0, receiptHeight - cornerLength, cornerWidth, cornerLength),
            (receiptWidth - cornerLength, receiptHeight - cornerWidth, cornerLength, cornerWidth),
            (receiptWidth - cornerWidth, receiptHeight - cornerLength, cornerWidth, cornerLength)
        ]
        
        for corner in corners {
            let cornerView = UIView(frame: CGRect(x: receiptRect.minX + corner.x,
                                                  y: receiptRect.minY + corner.y,
                                                  width: corner.width,
                                                  height: corner.height))
            cornerView.backgroundColor = .systemBlue
            cornerView.layer.cornerRadius = 2
            overlayView.addSubview(cornerView)
        }
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Postavite račun unutar okvira"
        instructionLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.clipsToBounds = true
        instructionLabel.frame = CGRect(x: (view.bounds.width - 280) / 2,
                                       y: receiptRect.maxY + 30,
                                       width: 280,
                                       height: 40)
        
        overlayView.addSubview(instructionLabel)
        view.addSubview(overlayView)
    }
    
    private func setupCaptureButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create circular button with camera icon
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        let image = UIImage(systemName: "camera.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 35
        button.clipsToBounds = true
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            button.widthAnchor.constraint(equalToConstant: 70),
            button.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        captureButton = button
    }
    
    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton?.transform = .identity
            }
        }
    }
}

// MARK: - Photo Capture Delegate

extension ReceiptScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        debugLog("📸 Photo captured in ReceiptScannerViewController")
        
        if let error = error {
            debugLog("❌ Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            debugLog("❌ Failed to get image data from photo")
            return
        }
        
        debugLog("✅ Photo converted to UIImage, size: \(image.size)")

        // Stop the camera off the main thread.
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }

        // Haptics and the capture callback belong on the main thread.
        DispatchQueue.main.async { [weak self] in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self?.onCapture?(image)
        }
    }
}

#Preview {
    QRScannerView { url in
        debugLog("Scanned URL: \(url)")
    } onReceiptParsed: { parsed in
        debugLog("Parsed receipt: \(parsed.merchantName)")
    }
}
