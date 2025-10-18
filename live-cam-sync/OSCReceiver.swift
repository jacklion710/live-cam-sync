//
//  OSCReceiver.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/18/25.
//

import Foundation
import Network

class OSCReceiver: ObservableObject {
    @Published var lastReceivedMessage: String = "Waiting for messages..."
    @Published var lastReceivedValue: String = ""
    @Published var isListening: Bool = false
    
    private var listener: NWListener?
    private var connection: NWConnection?
    
    // Starts listening for OSC messages on the specified IP and port
    func startListening(ipAddress: String, port: UInt16) {
        guard !isListening else { return }
        
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(ipAddress),
                port: NWEndpoint.Port(integerLiteral: port)
            )
            
            listener = try NWListener(using: parameters)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self?.isListening = true
                        self?.lastReceivedMessage = "Listening on \(ipAddress):\(port)..."
                    }
                    print("OSC Receiver: Listening on \(ipAddress):\(port)")
                case .failed(let error):
                    DispatchQueue.main.async {
                        self?.isListening = false
                        self?.lastReceivedMessage = "Error: \(error.localizedDescription)"
                    }
                    print("OSC Receiver: Failed with error: \(error)")
                case .cancelled:
                    DispatchQueue.main.async {
                        self?.isListening = false
                        self?.lastReceivedMessage = "Stopped listening"
                    }
                    print("OSC Receiver: Cancelled")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            DispatchQueue.main.async {
                self.lastReceivedMessage = "Failed to start: \(error.localizedDescription)"
            }
            print("OSC Receiver: Failed to create listener: \(error)")
        }
    }
    
    // Stops listening for OSC messages
    func stopListening() {
        listener?.cancel()
        connection?.cancel()
        listener = nil
        connection = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.lastReceivedMessage = "Stopped listening"
        }
        print("OSC Receiver: Stopped")
    }
    
    // Handles incoming UDP connections
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(on: connection)
    }
    
    // Receives data from the UDP connection
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.parseOSCMessage(data)
            }
            
            if let error = error {
                print("OSC Receiver: Receive error: \(error)")
            }
            
            // Continue receiving regardless of completion status for UDP datagrams
            self?.receiveData(on: connection)
        }
    }
    
    // Parses OSC message from raw data
    private func parseOSCMessage(_ data: Data) {
        let bytes = [UInt8](data)
        
        guard let addressEnd = bytes.firstIndex(of: 0) else {
            print("OSC Receiver: Invalid OSC message - no null terminator for address")
            return
        }
        
        guard let address = String(bytes: bytes[0..<addressEnd], encoding: .utf8) else {
            print("OSC Receiver: Failed to decode OSC address")
            return
        }
        
        let addressPaddedLength = ((addressEnd + 1) + 3) & ~3
        
        guard addressPaddedLength < bytes.count else {
            DispatchQueue.main.async {
                self.lastReceivedMessage = address
                self.lastReceivedValue = "(no arguments)"
            }
            print("OSC Receiver: Address: \(address), no type tag")
            return
        }
        
        guard let typeTagEnd = bytes[addressPaddedLength...].firstIndex(of: 0) else {
            print("OSC Receiver: Invalid OSC message - no null terminator for type tag")
            return
        }
        
        guard let typeTag = String(bytes: bytes[addressPaddedLength..<typeTagEnd], encoding: .utf8) else {
            print("OSC Receiver: Failed to decode type tag")
            return
        }
        
        let typeTagPaddedLength = ((typeTagEnd + 1) + 3) & ~3
        var argumentsIndex = typeTagPaddedLength
        
        var arguments: [String] = []
        
        for typeChar in typeTag.dropFirst() {
            guard argumentsIndex < bytes.count else { break }
            
            switch typeChar {
            case "i":
                guard argumentsIndex + 4 <= bytes.count else { break }
                let value = bytes[argumentsIndex..<argumentsIndex + 4].withUnsafeBytes {
                    Int32(bigEndian: $0.load(as: Int32.self))
                }
                arguments.append("\(value)")
                argumentsIndex += 4
                
            case "f":
                guard argumentsIndex + 4 <= bytes.count else { break }
                let value = bytes[argumentsIndex..<argumentsIndex + 4].withUnsafeBytes {
                    CFConvertFloat32SwappedToHost($0.load(as: CFSwappedFloat32.self))
                }
                arguments.append(String(format: "%.4f", value))
                argumentsIndex += 4
                
            case "s":
                guard let stringEnd = bytes[argumentsIndex...].firstIndex(of: 0) else { break }
                if let stringValue = String(bytes: bytes[argumentsIndex..<stringEnd], encoding: .utf8) {
                    arguments.append("\"\(stringValue)\"")
                }
                argumentsIndex = ((stringEnd + 1) + 3) & ~3
                
            case "b":
                guard argumentsIndex + 4 <= bytes.count else { break }
                let size = bytes[argumentsIndex..<argumentsIndex + 4].withUnsafeBytes {
                    Int32(bigEndian: $0.load(as: Int32.self))
                }
                argumentsIndex += 4 + Int(size)
                argumentsIndex = (argumentsIndex + 3) & ~3
                arguments.append("[blob: \(size) bytes]")
                
            default:
                print("OSC Receiver: Unsupported type tag: \(typeChar)")
            }
        }
        
        let argumentsString = arguments.isEmpty ? "(no arguments)" : arguments.joined(separator: ", ")
        
        DispatchQueue.main.async {
            self.lastReceivedMessage = address
            self.lastReceivedValue = argumentsString
        }
        
        print("OSC Receiver: \(address) -> \(argumentsString)")
    }
}

