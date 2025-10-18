//
//  HelpView.swift
//  live-cam-sync
//
//  Created by Jacob Leone on 10/18/25.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Getting Started")
                            .font(.title2).bold()
                        Text("1. On the OSC screen, set the IP to bind (use 0.0.0.0 to listen on all interfaces) and the UDP port (default 7400).\n2. Toggle ‘Enable Receiver’.\n3. Tap ‘Open Camera Recorder’. Grant Camera and Photos permissions when prompted.")
                    }
                    
                    Group {
                        Text("Controlling Recording via OSC")
                            .font(.title2).bold()
                        Text("Send OSC messages to the configured IP:port. The first argument controls recording:")
                        Text("- 1: start recording\n- 0: stop recording")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Group {
                        Text("Notes")
                            .font(.title2).bold()
                        Text("- Set your OSC sender to the phone’s IP on the same Wi‑Fi network.\n- To find your phone’s IPv4 address: Settings → Wi‑Fi → tap the ‘i’ next to your connected network → note the IPv4 Address. Enter this IP in your OSC sender.\n- Use 0.0.0.0 in the app to bind all interfaces if unsure.\n- The camera view also has a front/back toggle and maintains orientation.")
                    }
                }
                .padding()
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
