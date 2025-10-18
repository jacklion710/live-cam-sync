## Live Cam Sync (iOS)

A minimal SwiftUI app that:
- Receives OSC over UDP and displays the latest message/value
- Opens a camera recorder screen that starts/stops recording via OSC
- Saves recordings to the Photos camera roll with user confirmation

### Features
- OSC receiver with configurable IP and port (default: 0.0.0.0:7400)
- Start/Stop recording via OSC values: 1 starts, 0 stops
- Camera toggle: front/back
- Correct preview and recording orientation for portrait and landscape
- Save confirmation, progress HUD, and success/error toast

### Requirements
- Xcode 16.4+
- iOS 16+ (tested on modern iOS; project currently targets iOS set by Xcode template)
- Swift 5

### Build & Run
1. Open `live-cam-sync.xcodeproj` in Xcode.
2. Build and run on a real device (recommended for camera access).
3. When prompted, allow Camera and Photos permissions.

### Using the App
1. On launch, you land on the OSC Receiver screen:
   - Enter the IP to bind (e.g., `0.0.0.0` for all interfaces) and a UDP port.
   - Toggle “Enable Receiver” to start listening.
   - You’ll see the last OSC address and value received.
2. Tap “Open Camera Recorder” to enter the camera view:
   - The recorder listens to OSC values:
     - `1` → starts recording
     - `0` → stops recording
   - Use the camera switch button to toggle front/back cameras.
   - After recording stops, choose whether to save the video to Photos.

### OSC Examples
Send messages to the configured IP/port. The first value controls record state.

Python (python-osc):
```python
from pythonosc import udp_client

client = udp_client.SimpleUDPClient("127.0.0.1", 7400)
client.send_message("/record", 1)  # start
client.send_message("/record", 0)  # stop
```

TouchDesigner DAT or Max/MSP/PD can send similar messages with int/float 1 or 0.

### Permissions
This app requests:
- Camera: to capture video
- Microphone: to record audio with video
- Photos (Add Only): to save recordings to your camera roll

If you deny permissions, you can enable them later in iOS Settings.

### Troubleshooting
- No OSC updates: confirm IP/port, verify sender in same network, firewall/router rules, and that no other app is binding the same port.
- Orientation issues: rotate device to desired orientation before recording; the app updates preview/output orientation when the UI rotates.
- Duplicate start errors: the app debounces triggers and guards recorder state; ensure your OSC sender isn’t spamming repeated 1/1/1 events unnecessarily.
- Photos save prompt timing: the app requests add-only access early; if you denied it, enable Photos access in Settings.

### Project Structure (key files)
- `live-cam-sync/ContentView.swift` — OSC UI, configuration, navigation
- `live-cam-sync/OSCReceiver.swift` — UDP listener and basic OSC parser
- `live-cam-sync/CameraManager.swift` — AVFoundation capture and recording
- `live-cam-sync/CameraView.swift` — SwiftUI camera preview and controls

### License
I don’t care how people use the code. To make that explicit, this project is released under the Unlicense (public domain dedication). You can copy, modify, distribute, and use the code for any purpose without restrictions.

Add a `LICENSE` file with the Unlicense if you want, or just reference:
`https://unlicense.org/`

### Disclaimer
This is a minimal sample. Test thoroughly for your use case. Pull requests and issues are welcome.
