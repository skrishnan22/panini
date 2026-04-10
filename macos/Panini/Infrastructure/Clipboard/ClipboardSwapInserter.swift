import AppKit
import Carbon.HIToolbox
import Darwin
import Foundation

protocol ClipboardInserting {
    func pasteReplacingSelection(with text: String, targetProcessIdentifier: pid_t?) throws
}

final class ClipboardSwapInserter: ClipboardInserting {
    private struct ClipboardSnapshot {
        let plainText: String?
    }

    func pasteReplacingSelection(with text: String, targetProcessIdentifier: pid_t?) throws {
        if let targetProcessIdentifier {
            NSRunningApplication(processIdentifier: targetProcessIdentifier)?.activate(options: [])
        }

        let pasteboard = NSPasteboard.general
        let snapshot = captureSnapshot(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        AppLogger.accessibility.debug("Clipboard fallback: staged replacement text chars=\(text.count)")

        try simulatePasteShortcut()
        // Give target app a brief window to consume pasteboard text.
        usleep(120_000)

        restoreSnapshot(snapshot, to: pasteboard)
        AppLogger.accessibility.debug("Clipboard fallback: restored clipboard snapshot")
    }

    private func simulatePasteShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw PaniniError.writeFailed
        }

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            throw PaniniError.writeFailed
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func captureSnapshot(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        ClipboardSnapshot(plainText: pasteboard.string(forType: .string))
    }

    private func restoreSnapshot(_ snapshot: ClipboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if let plainText = snapshot.plainText {
            pasteboard.setString(plainText, forType: .string)
        }
    }
}
