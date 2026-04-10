import ApplicationServices
import AppKit
import Foundation

final class AccessibilityPermissionService {
    func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    func requestIfNeeded() {
        guard !isGranted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
