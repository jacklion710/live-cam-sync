//
//  CameraView.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/18/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var cameraManager = CameraManager()
    @ObservedObject var oscReceiver: OSCReceiver
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
                .onAppear {
                    cameraManager.configureSession()
                    cameraManager.startSession()
                }
                .onDisappear {
                    cameraManager.stopSession()
                }
                .onReceive(oscReceiver.$lastReceivedValue) { value in
                    let normalized = value.split(separator: ",").first.map(String.init) ?? value
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let intVal = Int(normalized) {
                        if intVal == 1 { cameraManager.startRecording() }
                        if intVal == 0 { cameraManager.stopRecording() }
                    } else if let doubleVal = Double(normalized) {
                        if doubleVal == 1 { cameraManager.startRecording() }
                        if doubleVal == 0 { cameraManager.stopRecording() }
                    }
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
            }
            .padding()
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
