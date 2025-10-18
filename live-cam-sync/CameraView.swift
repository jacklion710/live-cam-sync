//
//  CameraView.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/18/25.
//

import SwiftUI
import AVFoundation
import CoreGraphics

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var cameraManager = CameraManager()
    @ObservedObject var oscReceiver: OSCReceiver
    @State private var currentCaptureOrientation: AVCaptureVideoOrientation = .portrait
    @State private var showSavePrompt: Bool = false
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastIsSuccess: Bool = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            CameraPreview(session: cameraManager.session, orientation: currentCaptureOrientation)
                .ignoresSafeArea()
                .onAppear {
                    cameraManager.configureSession()
                    cameraManager.startSession()
                    updateCaptureOrientation()
                }
                .onDisappear {
                    cameraManager.stopSession()
                }
                .onReceive(oscReceiver.$lastReceivedValue) { value in
                    let normalized = value.split(separator: ",").first.map(String.init) ?? value
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // Debounce identical consecutive triggers to reduce duplicates
                    struct Static { static var lastCommand: String = "" }
                    if Static.lastCommand == normalized { return }
                    Static.lastCommand = normalized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        Static.lastCommand = ""
                    }
                    if let intVal = Int(normalized) {
                        if intVal == 1 { cameraManager.startRecording() }
                        if intVal == 0 { cameraManager.stopRecording() }
                    } else if let doubleVal = Double(normalized) {
                        if doubleVal == 1 { cameraManager.startRecording() }
                        if doubleVal == 0 { cameraManager.stopRecording() }
                    }
                }
                .onReceive(cameraManager.$lastRecordingURL) { url in
                    if url != nil { showSavePrompt = true }
                }
                .onReceive(cameraManager.$lastSaveMessage) { message in
                    guard let message = message else { return }
                    toastText = message
                    toastIsSuccess = (cameraManager.lastSaveSucceeded ?? false)
                    withAnimation { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { showToast = false }
                        cameraManager.lastSaveMessage = nil
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                    updateCaptureOrientation()
                }
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Spacer()
                
                HStack(spacing: 10) {
                    Circle()
                        .fill(cameraManager.isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(cameraManager.isRecording ? "Recording" : "Idle")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                
                Button(action: { cameraManager.toggleCamera() }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.black)
        .alert("Save Recording?", isPresented: $showSavePrompt) {
            Button("Discard", role: .destructive) {
                showSavePrompt = false
            }
            Button("Save") {
                cameraManager.saveLastRecordingToPhotoLibrary()
                showSavePrompt = false
            }
        } message: {
            Text("Would you like to save the recorded video to Photos?")
        }
        .overlay(alignment: .center) {
            if cameraManager.isSavingToPhotos {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Saving...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                Text(toastText)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background((toastIsSuccess ? Color.green : Color.red).opacity(0.9))
                    .cornerRadius(10)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // O(1)
    // Maps current device/interface orientation to capture orientation and applies it
    private func updateCaptureOrientation() {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let fallbackIO = windowScene?.interfaceOrientation
        let dev = UIDevice.current.orientation
        let newOrientation = captureOrientation(for: dev, fallback: fallbackIO)
        currentCaptureOrientation = newOrientation

        // Update movie output orientation via manager on main actor
        Task { @MainActor in
            cameraManager.updateOrientation(newOrientation)
        }
    }
}

// O(1)
// Single source of truth mapper for device/interface orientation to capture orientation
fileprivate func captureOrientation(for o: UIDeviceOrientation,
                                    fallback: UIInterfaceOrientation?) -> AVCaptureVideoOrientation {
    switch o {
    case .portrait: return .portrait
    case .portraitUpsideDown: return .portraitUpsideDown
    case .landscapeLeft: return .landscapeRight // device left = camera right
    case .landscapeRight: return .landscapeLeft
    default:
        if let io = fallback {
            switch io {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            default: return .portrait
            }
        }
        return .portrait
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let orientation: AVCaptureVideoOrientation
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
            if connection.isVideoMirroringSupported { connection.automaticallyAdjustsVideoMirroring = true }
        }
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        (layer as? AVCaptureVideoPreviewLayer)?.backgroundColor = UIColor.black.cgColor
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        (layer as? AVCaptureVideoPreviewLayer)?.backgroundColor = UIColor.black.cgColor
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}
