//
//  CameraManager.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/18/25.
//

import Foundation
import AVFoundation
import Photos
import Combine

final class CameraManager: NSObject, ObservableObject {
    // O(1) - simple property accessors
    // Manages the camera capture session and video recording lifecycle.
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraSession.Queue")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var outputFileURL: URL?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    // O(1)
    func checkPermissions() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = granted ? .authorized : .denied
                }
            }
        }
    }
    
    // O(1) - performs fixed setup steps
    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            // Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video) else {
                print("CameraManager: No video device available")
                self.session.commitConfiguration()
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.videoDeviceInput = videoInput
                }
            } catch {
                print("CameraManager: Failed to create video input: \(error)")
                self.session.commitConfiguration()
                return
            }
            
            // Output
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    // O(1)
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    // O(1)
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    // O(1)
    func startRecording() {
        guard !isRecording else { return }
        checkPermissions()
        guard authorizationStatus == .authorized else {
            print("CameraManager: Camera permission not granted")
            return
        }
        
        // Prepare temp file URL
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("live_cam_sync_\(UUID().uuidString).mov")
        outputFileURL = fileURL
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            
            if self.movieOutput.isRecording { return }
            
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .standard
                }
            }
            
            self.movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecording = true }
        }
    }
    
    // O(1)
    func stopRecording() {
        guard isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
        }
    }
    
    // O(1)
    private func saveToPhotoLibrary(fileURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("CameraManager: Photos permission not granted")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }) { success, error in
                if let error = error {
                    print("CameraManager: Failed to save video: \(error)")
                } else {
                    print("CameraManager: Saved video to Photos: \(success)")
                }
            }
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    // O(1)
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }
        if let error = error {
            print("CameraManager: Recording finished with error: \(error)")
        } else {
            saveToPhotoLibrary(fileURL: outputFileURL)
        }
    }
}
