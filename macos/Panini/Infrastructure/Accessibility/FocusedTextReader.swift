import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Darwin
import Foundation

protocol TextReader {
    func currentSelection() throws -> String
    func captureSession(targetProcessIdentifier: pid_t?) throws -> TextEditingSession
}

protocol AXTextElement {
    func value(for attribute: String) -> AnyObject?
}

protocol FocusedElementProviding {
    func focusedElement() -> AXTextElement?
}

final class AXTextElementRef: AXTextElement {
    let raw: AXUIElement

    init(raw: AXUIElement) {
        self.raw = raw
    }

    func value(for attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(raw, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value
    }
}

final class DefaultFocusedElementProvider: FocusedElementProviding, @unchecked Sendable {
    static let shared = DefaultFocusedElementProvider()

    func focusedElement() -> AXTextElement? {
        let systemWide = AXUIElementCreateSystemWide()

        let candidates: [AXUIElement?] = [
            copyAXUIElementAttribute(kAXFocusedUIElementAttribute as String, from: systemWide),
            focusedElementFromFocusedApplication(systemWide),
            focusedElementFromFrontmostApplication(),
        ]

        for candidate in candidates {
            if let candidate {
                return AXTextElementRef(raw: candidate)
            }
        }

        return nil
    }

    private func frontmostApplicationElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func focusedElementFromFrontmostApplication() -> AXUIElement? {
        guard let appElement = frontmostApplicationElement() else { return nil }
        return copyAXUIElementAttribute(kAXFocusedUIElementAttribute as String, from: appElement)
            ?? focusedElementFromWindow(appElement)
    }

    private func focusedElementFromFocusedApplication(_ systemWide: AXUIElement) -> AXUIElement? {
        guard let appElement = copyAXUIElementAttribute(kAXFocusedApplicationAttribute as String, from: systemWide) else {
            return nil
        }

        return copyAXUIElementAttribute(kAXFocusedUIElementAttribute as String, from: appElement)
            ?? focusedElementFromWindow(appElement)
    }

    private func focusedElementFromWindow(_ element: AXUIElement) -> AXUIElement? {
        guard let window = copyAXUIElementAttribute(kAXFocusedWindowAttribute as String, from: element) else {
            return nil
        }

        return copyAXUIElementAttribute(kAXFocusedUIElementAttribute as String, from: window) ?? window
    }

    private func copyAXUIElementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}

final class FocusedTextReader: TextReader {
    private struct CapturedSelection {
        let text: String
        let range: CFRange?
        let fullValue: String?
        let readStrategy: AXReadStrategy
    }

    private let provider: FocusedElementProviding
    private let maxReadAttempts: Int
    private let readRetryDelayMicroseconds: useconds_t
    private let clipboardPollAttempts: Int
    private let clipboardPollIntervalMicroseconds: useconds_t

    init(
        provider: FocusedElementProviding,
        maxReadAttempts: Int = 4,
        readRetryDelayMicroseconds: useconds_t = 50_000,
        clipboardPollAttempts: Int = 10,
        clipboardPollIntervalMicroseconds: useconds_t = 50_000
    ) {
        self.provider = provider
        self.maxReadAttempts = max(1, maxReadAttempts)
        self.readRetryDelayMicroseconds = readRetryDelayMicroseconds
        self.clipboardPollAttempts = max(1, clipboardPollAttempts)
        self.clipboardPollIntervalMicroseconds = clipboardPollIntervalMicroseconds
    }

    func currentSelection() throws -> String {
        try captureSession(targetProcessIdentifier: nil).selectedText
    }

    func captureSession(targetProcessIdentifier: pid_t?) throws -> TextEditingSession {
        for attempt in 0 ..< maxReadAttempts {
            if let element = provider.focusedElement() as? AXInspectableTextElement,
               let session = capturedSession(
                   from: element,
                   targetProcessIdentifier: targetProcessIdentifier
               )
            {
                return session
            }

            if attempt < maxReadAttempts - 1 {
                usleep(readRetryDelayMicroseconds)
            }
        }

        AppLogger.accessibility.error("No focused element from AX provider after \(self.maxReadAttempts) attempts.")
        throw PaniniError.selectionUnavailable
    }

    private func tryClipboardSelectionFallback() -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        let sentinel = "__PANINI_COPY_SENTINEL__\(UUID().uuidString)"

        do {
            pasteboard.clearContents()
            pasteboard.setString(sentinel, forType: .string)

            try simulateCopyShortcut()
            let selection = pollPasteboardSelection(from: pasteboard, sentinel: sentinel)

            snapshot.restore(to: pasteboard)

            guard let selection, !selection.isEmpty, selection != sentinel else {
                AppLogger.accessibility.error("Clipboard fallback did not capture a new selection.")
                return nil
            }

            return selection
        } catch {
            AppLogger.accessibility.error("Clipboard selection fallback failed: \(error.localizedDescription, privacy: .public)")
            snapshot.restore(to: pasteboard)
            return nil
        }
    }

    private func capturedSession(from element: AXInspectableTextElement, targetProcessIdentifier: pid_t?) -> TextEditingSession? {
        let capabilities = AXElementCapabilities.snapshot(from: element)
        guard let selection = resolveSelection(from: element, capabilities: capabilities) else {
            return nil
        }

        return TextEditingSession(
            targetProcessIdentifier: targetProcessIdentifier,
            element: element,
            capabilities: capabilities,
            selectedText: selection.text,
            selectedRange: selection.range,
            fullValue: selection.fullValue,
            readStrategy: selection.readStrategy,
            writeStrategy: resolveWriteStrategy(
                capabilities: capabilities,
                hasRange: selection.range != nil,
                hasValue: selection.fullValue != nil
            )
        )
    }

    private func resolveSelection(from element: AXInspectableTextElement, capabilities: AXElementCapabilities) -> CapturedSelection? {
        if let selected = normalizedText(from: element.value(for: kAXSelectedTextAttribute as String)) {
            AppLogger.accessibility.debug("AX selectedText read succeeded chars=\(selected.count)")
            return CapturedSelection(
                text: selected,
                range: nil,
                fullValue: normalizedText(from: element.value(for: kAXValueAttribute as String)),
                readStrategy: .selectedTextAttribute
            )
        }

        if capabilities.supportedAttributes.contains(kAXSelectedTextRangeAttribute as String),
           capabilities.supportedParameterizedAttributes.contains(kAXStringForRangeParameterizedAttribute as String),
           let range = copySelectedRange(from: element),
           let selected = stringForRange(range, from: element)
        {
            AppLogger.accessibility.debug("AX selectedTextRange read succeeded chars=\(selected.count)")
            return CapturedSelection(
                text: selected,
                range: range,
                fullValue: normalizedText(from: element.value(for: kAXValueAttribute as String)),
                readStrategy: .selectedTextRange
            )
        }

        if let fallback = tryClipboardSelectionFallback() {
            AppLogger.accessibility.info("Using clipboard fallback selection chars=\(fallback.count)")
            return CapturedSelection(
                text: fallback,
                range: nil,
                fullValue: normalizedText(from: element.value(for: kAXValueAttribute as String)),
                readStrategy: .clipboardFallback
            )
        }

        AppLogger.accessibility.error("AX read failed and clipboard fallback empty.")
        return nil
    }

    private func copySelectedRange(from element: AXInspectableTextElement) -> CFRange? {
        guard let rawValue = element.value(for: kAXSelectedTextRangeAttribute as String) else {
            return nil
        }

        guard CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        let value = rawValue as! AXValue
        guard AXValueGetType(value) == .cfRange else {
            return nil
        }

        var range = CFRange()
        let copied = AXValueGetValue(value, .cfRange, &range)
        return copied ? range : nil
    }

    private func stringForRange(_ range: CFRange, from element: AXInspectableTextElement) -> String? {
        var mutableRange = range
        guard let parameter = AXValueCreate(.cfRange, &mutableRange) else {
            return nil
        }

        return normalizedText(
            from: element.parameterizedValue(
                for: kAXStringForRangeParameterizedAttribute as String,
                parameter: parameter
            )
        )
    }

    private func resolveWriteStrategy(
        capabilities: AXElementCapabilities,
        hasRange: Bool,
        hasValue: Bool
    ) -> AXWriteStrategy {
        if capabilities.settableAttributes.contains(kAXSelectedTextAttribute as String) {
            return .selectedTextAttribute
        }

        if hasRange,
           hasValue,
           capabilities.settableAttributes.contains(kAXValueAttribute as String)
        {
            return .valueAndSelectedTextRange
        }

        return .clipboardFallback
    }

    private func normalizedText(from rawValue: AnyObject?) -> String? {
        guard let text = rawValue as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }

    private func pollPasteboardSelection(from pasteboard: NSPasteboard, sentinel: String) -> String? {
        for attempt in 0 ..< clipboardPollAttempts {
            let selection = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let selection, !selection.isEmpty, selection != sentinel {
                return selection
            }

            if attempt < clipboardPollAttempts - 1 {
                usleep(clipboardPollIntervalMicroseconds)
            }
        }

        return nil
    }

    private func simulateCopyShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw PaniniError.selectionUnavailable
        }

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            throw PaniniError.selectionUnavailable
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

}
