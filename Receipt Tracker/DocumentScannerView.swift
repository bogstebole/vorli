//
//  DocumentScannerView.swift
//  Receipt Tracker
//
//  SwiftUI wrapper around VisionKit's document scanner. It auto-detects the
//  receipt edges, deskews, and enhances the image before handing it back.
//

import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: (UIImage) -> Void
    var onCancel: () -> Void
    var onError: (Error) -> Void = { _ in }

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                parent.onCancel()
                return
            }
            // Use the most recently captured page.
            let image = scan.imageOfPage(at: scan.pageCount - 1)
            parent.onScan(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}
