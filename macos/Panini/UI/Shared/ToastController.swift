import AppKit
import Foundation
import Combine

@MainActor
final class ToastController: ObservableObject, ToastPresenting {
    @Published private(set) var lastMessage: String?

    private var action: (() -> Void)?

    func show(message: String, actionTitle: String?, action: (() -> Void)?) {
        AppLogger.coordinator.info("Toast message: \(message, privacy: .public)")
        lastMessage = message
        self.action = action

        // We currently don't have a rendered toast surface.
        // Use modal alerts only for failure states.
        if actionTitle == nil && shouldPresentAlert(for: message) {
            presentInfoAlert(message: message)
        }

        if actionTitle != nil {
            Task {
                try? await Task.sleep(for: .seconds(10))
                self.action = nil
            }
        }
    }

    func triggerAction() {
        action?()
        action = nil
    }

    private func presentInfoAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Panini"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func shouldPresentAlert(for message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("error")
            || normalized.contains("failed")
            || normalized.contains("unavailable")
            || normalized.contains("no selected text")
            || normalized.contains("cannot")
            || normalized.contains("unable")
    }
}
