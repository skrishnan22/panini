import ApplicationServices
import AppKit
import Foundation

protocol TextWriter {
    func replaceSelection(with text: String) throws
    func replaceSelection(in session: TextEditingSession, with text: String) throws
}

protocol AXTextWritableElement: AXInspectableTextElement {
    func setValue(_ value: AnyObject, for attribute: String) -> AXError
}

final class AXTextWritableElementRef: AXTextWritableElement {
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

    func setValue(_ value: AnyObject, for attribute: String) -> AXError {
        AXUIElementSetAttributeValue(raw, attribute as CFString, value)
    }
}

final class DefaultWritableFocusedElementProvider: FocusedElementProviding, @unchecked Sendable {
    static let shared = DefaultWritableFocusedElementProvider()

    func focusedElement() -> AXTextElement? {
        let systemWide = AXUIElementCreateSystemWide()

        let candidates: [AXUIElement?] = [
            copyAXUIElementAttribute(kAXFocusedUIElementAttribute as String, from: systemWide),
            focusedElementFromFocusedApplication(systemWide),
            focusedElementFromFrontmostApplication(),
        ]

        for candidate in candidates {
            if let candidate {
                return AXTextWritableElementRef(raw: candidate)
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

final class FocusedTextWriter: TextWriter {
    private let provider: FocusedElementProviding

    init(provider: FocusedElementProviding = DefaultWritableFocusedElementProvider.shared) {
        self.provider = provider
    }

    func replaceSelection(with text: String) throws {
        guard let element = provider.focusedElement() as? AXTextWritableElement else {
            throw PaniniError.writeFailed
        }

        try replaceSelection(text, on: element, attribute: kAXSelectedTextAttribute as String)
    }

    func replaceSelection(in session: TextEditingSession, with text: String) throws {
        guard let element = session.element as? AXTextWritableElement else {
            throw PaniniError.writeFailed
        }

        switch session.writeStrategy {
        case .selectedTextAttribute:
            try replaceSelection(text, on: element, attribute: kAXSelectedTextAttribute as String)
        case .valueAndSelectedTextRange:
            guard let range = session.selectedRange, let fullValue = session.fullValue else {
                throw PaniniError.writeFailed
            }

            let nsValue = fullValue as NSString
            let nsRange = NSRange(location: range.location, length: range.length)
            guard NSMaxRange(nsRange) <= nsValue.length else {
                throw PaniniError.writeFailed
            }

            let replacement = nsValue.replacingCharacters(in: nsRange, with: text)
            try replaceSelection(replacement, on: element, attribute: kAXValueAttribute as String)
        case .clipboardFallback:
            throw PaniniError.writeFailed
        }
    }

    private func replaceSelection(
        _ text: String,
        on element: AXTextWritableElement,
        attribute: String
    ) throws {
        let writeError = element.setValue(text as NSString, for: attribute)
        guard writeError == .success else {
            throw PaniniError.writeFailed
        }
    }
}
