# OpenExo GUI — iOS/iPadOS App

A native SwiftUI replacement for the OpenExo Python desktop GUI, built for iPhone and iPad.

## Features
- BLE scan, connect, and reconnect to the exoskeleton (Nordic UART Service)
- Real-time dual charts for torque, angle, and FSR data at 30Hz
- Active trial management — start, pause, mark, and end trials
- CSV data logging to the device Documents folder
- Advanced controller parameter tuning (joint / controller / param / value)
- Biofeedback screen with FSR goal detection and haptic feedback
- Mock mode for simulator testing (flip `MOCK_MODE` in `BLEManager.swift`)
- Adaptive layout for iPhone and iPad

## Requirements
- iOS 16.1+
- Xcode 16+ (for iOS 18 device support)

## Usage
1. Open `OpenExo GUI.xcodeproj` in Xcode
2. Select your iPhone or iPad as the target device
3. Build and run (⌘R)
4. Scan for nearby exoskeleton devices, connect, calibrate, and start a trial

## Mock Mode
Set `MOCK_MODE = true` in `BLEManager.swift` to run with simulated data in the iOS Simulator.  
Set to `false` when running on a real device with the exoskeleton hardware.

## Switching to Real Hardware
Only one line needs to change in `BLEManager.swift`:
```swift
let MOCK_MODE = false
```
