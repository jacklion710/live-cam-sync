//
//  ContentView.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var oscReceiverInstance = OSCReceiver()
    @State private var ipAddressInput: String = "0.0.0.0"
    @State private var portInput: String = "7400"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("OSC Receiver")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 20) {
                    VStack(spacing: 15) {
                        HStack {
                            Text("IP Address:")
                                .font(.subheadline)
                                .frame(width: 100, alignment: .leading)
                            
                            TextField("0.0.0.0", text: $ipAddressInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .disabled(oscReceiverInstance.isListening)
                        }
                        
                        HStack {
                            Text("Port:")
                                .font(.subheadline)
                                .frame(width: 100, alignment: .leading)
                            
                            TextField("7400", text: $portInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                                .disabled(oscReceiverInstance.isListening)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    
                    HStack {
                        Text("Enable Receiver")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { oscReceiverInstance.isListening },
                            set: { isEnabled in
                                if isEnabled {
                                    if let port = UInt16(portInput) {
                                        oscReceiverInstance.startListening(ipAddress: ipAddressInput, port: port)
                                    }
                                } else {
                                    oscReceiverInstance.stopListening()
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: oscReceiverInstance.isListening ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                                .foregroundColor(oscReceiverInstance.isListening ? .green : .gray)
                                .font(.title2)
                            
                            Text(oscReceiverInstance.isListening ? "\(ipAddressInput):\(portInput)" : "Not listening")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Last Message Address:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(oscReceiverInstance.lastReceivedMessage)
                                .font(.system(.body, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Last Value:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(oscReceiverInstance.lastReceivedValue)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.semibold)
                                .padding(15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
                
                NavigationLink(destination: CameraView(oscReceiver: oscReceiverInstance)) {
                    HStack(spacing: 8) {
                        Image(systemName: "video.fill")
                        Text("Open Camera Recorder")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 400)
            .navigationTitle("Live Cam Sync")
        }
    }
}

#Preview {
    ContentView()
}
