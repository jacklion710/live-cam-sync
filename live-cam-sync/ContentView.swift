//
//  ContentView.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var oscReceiverInstance = OSCReceiver(port: 7400)
    
    var body: some View {
        VStack(spacing: 30) {
            Text("OSC Receiver")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 20) {
                HStack {
                    Text("Enable Receiver")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { oscReceiverInstance.isListening },
                        set: { isEnabled in
                            if isEnabled {
                                oscReceiverInstance.startListening()
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
                        
                        Text("Port: 7400")
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
        }
        .padding()
        .frame(minWidth: 400, minHeight: 400)
    }
}

#Preview {
    ContentView()
}
