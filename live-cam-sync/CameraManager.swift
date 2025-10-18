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
import CoreGraphics

final class CameraManager: NSObject, ObservableObject {
    // O(1) - simple property accessors
    // Manages the camera capture session and video recording lifecycle.
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var lastRecordingURL: URL?
    @Published var isSavingToPhotos: Bool = false
    @Published var lastSaveSucceeded: Bool?
    @Published var lastSaveMessage: String?
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraSession.Queue")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var outputFileURL: URL?
    private var isStartingRecording: Bool = false
    
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

    // O(1)
    func requestPhotoLibraryAddAccess(completion: ((PHAuthorizationStatus) -> Void)? = nil) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                completion?(status)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                completion?(status)
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

            // Audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                        self.audioDeviceInput = audioInput
                    }
                } catch {
                    print("CameraManager: Failed to create audio input: \(error)")
                }
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
        if isRecording || isStartingRecording { return }
        isStartingRecording = true
        DispatchQueue.main.async { [weak self] in self?.isRecording = true }
        checkPermissions()
        guard authorizationStatus == .authorized else {
            print("CameraManager: Camera permission not granted")
            isStartingRecording = false
            DispatchQueue.main.async { [weak self] in self?.isRecording = false }
            return
        }
        // Proactively request Photos add permission so prompt appears early
        requestPhotoLibraryAddAccess(completion: nil)
        
        // Prepare temp file URL
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempDir.appendingPathComponent("live_cam_sync_\(UUID().uuidString).mov")
        outputFileURL = fileURL
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            
            if self.movieOutput.isRecording {
                self.isStartingRecording = false
                return
            }
            
            if let connection = self.movieOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .standard }
                // Orientation is managed live via updateOrientation(_:)
            }
            
            self.movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecording = true }
            self.isStartingRecording = false
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
    func saveLastRecordingToPhotoLibrary() {
        guard let fileURL = lastRecordingURL else { return }
        isSavingToPhotos = true
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in
                self.performSave(fileURL: fileURL)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { _ in
                self.performSave(fileURL: fileURL)
            }
        }
    }

    private func performSave(fileURL: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }) { success, error in
            DispatchQueue.main.async {
                self.isSavingToPhotos = false
                if let error = error {
                    self.lastSaveSucceeded = false
                    self.lastSaveMessage = "Failed to save: \(error.localizedDescription)"
                } else {
                    self.lastSaveSucceeded = success
                    self.lastSaveMessage = success ? "Saved to Photos" : "Failed to save"
                }
            }
        }
    }

    // O(1)
    // Applies the given capture orientation to all relevant video connections.
    @MainActor
    func updateOrientation(_ orientation: AVCaptureVideoOrientation) {
        let apply: (AVCaptureConnection) -> Void = { conn in
            if conn.isVideoOrientationSupported {
                conn.videoOrientation = orientation
            }
            if conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = true
            }
        }

        // Movie output must be set on the session queue
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let c = self.movieOutput.connection(with: .video) {
                apply(c)
            }
        }
    }

    // Toggle between front and back cameras
    func toggleCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let currentInput = self.videoDeviceInput else { return }
            let currentPosition = currentInput.device.position
            let preferredPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInUltraWideCamera, .builtInTripleCamera]
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: preferredPosition)
            guard let newDevice = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition) else {
                print("CameraManager: No camera available for position \(preferredPosition)")
                return
            }
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                self.session.beginConfiguration()
                self.session.removeInput(currentInput)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                } else {
                    if self.session.canAddInput(currentInput) { self.session.addInput(currentInput) }
                }
                self.session.commitConfiguration()
            } catch {
                print("CameraManager: Failed to switch camera: \(error)")
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
            DispatchQueue.main.async { [weak self] in
                self?.lastRecordingURL = outputFileURL
                self?.lastSaveSucceeded = false
                self?.lastSaveMessage = "Recording finished with error: \(error.localizedDescription)"
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lastRecordingURL = outputFileURL
            }
        }
    }
}
