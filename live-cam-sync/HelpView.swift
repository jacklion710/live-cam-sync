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
                VStack(alignment: .leading, spacing: 20) {
                    SectionCard(title: "Quick Start", systemImage: "bolt.fill") {
                        StepRow(stepNumber: 1, text: "On the OSC screen, set IP (e.g. 0.0.0.0) and port (7400 by default).")
                        StepRow(stepNumber: 2, text: "Toggle ‘Enable Receiver’ to start listening.")
                        StepRow(stepNumber: 3, text: "Tap ‘Open Camera Recorder’. Allow Camera and Photos when asked.")
                    }

                    SectionCard(title: "Send OSC to Control Recording", systemImage: "antenna.radiowaves.left.and.right") {
                        Text("Send messages to the configured IP:port. First argument controls recording:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        PillRow(label: "1 → start recording", color: .green)
                        PillRow(label: "0 → stop recording", color: .red)
                    }

                    SectionCard(title: "Find Your iPhone IP (IPv4)", systemImage: "network") {
                        StepRow(stepNumber: 1, text: "Open Settings → Wi‑Fi.")
                        StepRow(stepNumber: 2, text: "Tap the ‘i’ next to your connected network.")
                        StepRow(stepNumber: 3, text: "Note the IPv4 Address and enter it in your OSC sender.")
                        BulletRow(text: "Sender and phone must be on the same Wi‑Fi network.")
                    }

                    SectionCard(title: "Tips", systemImage: "lightbulb.fill") {
                        BulletRow(text: "Use 0.0.0.0 in the app to bind all interfaces if unsure.")
                        BulletRow(text: "Use the camera toggle to switch front/back.")
                        BulletRow(text: "The app adjusts preview and recording orientation automatically.")
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

// MARK: - Components

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                Text(title).font(.title3).bold()
            }
            content
        }
        .padding(16)
        .background(Color.gray.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

private struct StepRow: View {
    let stepNumber: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(stepNumber)")
                .font(.footnote).bold()
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct BulletRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.secondary)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct PillRow: View {
    let label: String
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(color.opacity(0.9))
            .cornerRadius(8)
    }
}
