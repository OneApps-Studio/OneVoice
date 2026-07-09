import AVFoundation
import ApplicationServices
import CoreGraphics
import Speech

enum MacPermissions {
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    static var hasInputMonitoring: Bool {
        CGPreflightListenEventAccess()
    }

    static var hasMicrophone: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var hasSpeechRecognition: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    static func requestSpeechRecognition() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }
}
