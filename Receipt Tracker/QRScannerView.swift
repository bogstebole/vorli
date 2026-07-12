//
//  QRScannerView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//
//  One scanning surface: the QR camera is live by default, and a bottom
//  action bar offers the two alternatives — document scanner (OCR) and the
//  photo library. A picked photo figures out on its own whether it holds a
//  QR code or needs OCR.
//

import SwiftUI
import AVFoundation
import PhotosUI

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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    /// True from the moment the user taps "Račun" until the document scanner
    /// is dismissed — removes the QR camera so it releases the device.
    @State private var docScannerRequested = false
    @State private var showDocScanner = false

    init(onScan: @escaping (String) -> Void, onReceiptParsed: ((ParsedReceipt) -> Void)? = nil) {
        self.onScan = onScan
        self.onReceiptParsed = onReceiptParsed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isAuthorized {
                    if docScannerRequested {
                        Color.black.ignoresSafeArea()
                    } else {
                        QRScannerCameraView(onScan: { url in
                            onScan(url)
                            dismiss()
                        })
                        .ignoresSafeArea()
                    }
                } else {
                    permissionView
                }

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
            .safeAreaInset(edge: .bottom) {
                if isAuthorized {
                    actionBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Skeniraj")
            .navigationBarTitleDisplayMode(.inline)
            // Camera runs edge-to-edge; the bar is just floating chrome.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Skeniraj")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
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
            Task { await handlePickedPhoto(newValue) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .qrScannerSessionDidStop)) { _ in
            if docScannerRequested && !showDocScanner {
                showDocScanner = true
            }
        }
        .fullScreenCover(isPresented: $showDocScanner) {
            DocumentScannerView(
                onScan: { image in
                    closeDocScanner()
                    handleReceiptCapture(image)
                },
                onCancel: { closeDocScanner() },
                onError: { error in
                    closeDocScanner()
                    errorMessage = "Greška skenera: \(error.localizedDescription)"
                    showError = true
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Bottom action bar

    /// Compact circular icon buttons with labels underneath — the same
    /// control language as the system document scanner. QR is the live
    /// default, so its button is the prominent one.
    private var actionBar: some View {
        HStack(spacing: 24) {
            circleAction(icon: "qrcode.viewfinder", title: "QR kod", isActive: true) {
                // Already the default surface — nothing to switch.
            }
            circleAction(icon: "doc.viewfinder", title: "Račun", isActive: false) {
                openDocScanner()
            }
            VStack(spacing: 6) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    circleIcon("photo", isActive: false)
                }
                .buttonStyle(.plain)
                actionCaption("Galerija")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func circleAction(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                circleIcon(icon, isActive: isActive)
            }
            .buttonStyle(.plain)
            actionCaption(title)
        }
    }

    /// True circle: glassEffect applied directly (the glass button style adds
    /// its own horizontal padding and turns everything into a pill).
    private func circleIcon(_ icon: String, isActive: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(isActive ? Color(uiColor: .systemBackground) : .primary)
            .frame(width: 48, height: 48)
            .glassEffect(
                isActive ? .regular.tint(.primary).interactive() : .regular.interactive(),
                in: .circle
            )
    }

    private func actionCaption(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3)
    }

    // MARK: - Document scanner handoff

    private func openDocScanner() {
        guard DocumentScannerView.isSupported else {
            errorMessage = "Skener dokumenata nije podržan na ovom uređaju."
            showError = true
            return
        }
        // Removing the camera view stops the QR session; its "stopped"
        // notification presents the scanner as soon as the device is free.
        docScannerRequested = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if docScannerRequested && !showDocScanner {
                showDocScanner = true
            }
        }
    }

    private func closeDocScanner() {
        showDocScanner = false
        docScannerRequested = false
    }

    // MARK: - Picked photo (auto-detect: QR first, OCR fallback)

    private func handlePickedPhoto(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem else { return }
        selectedPhoto = nil

        isProcessing = true
        guard let imageData = try? await photoItem.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: imageData) else {
            isProcessing = false
            errorMessage = "Neuspešno učitavanje slike"
            showError = true
            return
        }

        if let qrCode = decodeQRCode(from: uiImage) {
            isProcessing = false
            onScan(qrCode)
            dismiss()
        } else {
            // No QR in the photo — treat it as a receipt photo and run OCR.
            handleReceiptCapture(uiImage)
        }
    }

    private func decodeQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: CIContext(),
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }

    // MARK: - OCR

    /// May be called from a background thread, so all state mutation is
    /// funneled onto the main actor.
    private func handleReceiptCapture(_ image: UIImage) {
        Task { @MainActor in
            isProcessing = true
            do {
                let parsedReceipt = try await ReceiptOCRParser.parseReceipt(from: image)
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

    // MARK: - Permissions

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("Potreban pristup kameri")
                .font(.system(.title2, design: .monospaced, weight: .bold))

            Text("Da bi skenirao račune, omogući pristup kameri u podešavanjima.")
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
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
        }
        .padding()
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

        // Preview layer attaches immediately; frames appear once the session
        // is configured and started on the session queue.
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

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

    private func failed() {
        let ac = UIAlertController(title: "Skeniranje nije podržano",
                                   message: "Vaš uređaj ne podržava skeniranje QR kodova.",
                                   preferredStyle: .alert)
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

#Preview {
    QRScannerView { url in
        print("Scanned URL: \(url)")
    } onReceiptParsed: { parsed in
        print("Parsed receipt: \(parsed.merchantName)")
    }
}
