import ApplicationServices
import XCTest
@testable import GrammarAI

private final class MockAXElement: AXTextWritableElement {
    var attributes: [String: AnyObject] = [:]
    var nextWriteError: AXError = .success

    func value(for attribute: String) -> AnyObject? {
        attributes[attribute]
    }

    func attributeNames() -> [String] { [] }

    func parameterizedAttributeNames() -> [String] { [] }

    func isAttributeSettable(_ attribute: String) -> Bool { true }

    func parameterizedValue(for attribute: String, parameter: AnyObject) -> AnyObject? { nil }

    func setValue(_ value: AnyObject, for attribute: String) -> AXError {
        attributes[attribute] = value
        return nextWriteError
    }
}

private struct MockFocusedProvider: FocusedElementProviding {
    let element: AXTextElement?
    func focusedElement() -> AXTextElement? { element }
}

private final class EventuallyFocusedProvider: FocusedElementProviding {
    private var elements: [AXTextElement?]

    init(elements: [AXTextElement?]) {
        self.elements = elements
    }

    func focusedElement() -> AXTextElement? {
        guard !elements.isEmpty else { return nil }
        return elements.removeFirst()
    }
}

final class FocusedTextIOTests: XCTestCase {
    private func makeSession(
        element: AXInspectableTextElement,
        selectedText: String,
        selectedRange: CFRange? = nil,
        fullValue: String? = nil,
        writeStrategy: AXWriteStrategy
    ) -> TextEditingSession {
        TextEditingSession(
            targetProcessIdentifier: 99,
            element: element,
            capabilities: AXElementCapabilities(
                supportedAttributes: [],
                supportedParameterizedAttributes: [],
                settableAttributes: []
            ),
            selectedText: selectedText,
            selectedRange: selectedRange,
            fullValue: fullValue,
            readStrategy: .selectedTextAttribute,
            writeStrategy: writeStrategy
        )
    }

    func testCaptureSessionStoresTargetPidSelectedTextAndResolvedStrategies() throws {
        let element = MockAXCapabilityElement(
            attributes: [
                kAXSelectedTextAttribute as String: "teh" as NSString,
            ],
            attributeNames: [
                kAXSelectedTextAttribute as String,
            ],
            settableAttributes: [
                kAXSelectedTextAttribute as String,
            ]
        )

        let reader = FocusedTextReader(provider: MockFocusedProvider(element: element))
        let session = try reader.captureSession(targetProcessIdentifier: 123)

        XCTAssertEqual(session.targetProcessIdentifier, 123)
        XCTAssertEqual(session.selectedText, "teh")
        XCTAssertEqual(session.readStrategy, .selectedTextAttribute)
        XCTAssertEqual(session.writeStrategy, .selectedTextAttribute)
    }

    func testReadUsesSelectedTextRangeAndStringForRangeWhenSelectedTextMissing() throws {
        let element = MockAXCapabilityElement(
            attributes: [
                kAXSelectedTextRangeAttribute as String: makeAXRangeValue(CFRange(location: 2, length: 3)),
                kAXValueAttribute as String: "teh body" as NSString,
            ],
            attributeNames: [
                kAXSelectedTextRangeAttribute as String,
                kAXValueAttribute as String,
            ],
            parameterizedAttributeNames: [
                kAXStringForRangeParameterizedAttribute as String,
            ],
            settableAttributes: [
                kAXValueAttribute as String,
            ],
            parameterizedValues: [
                kAXStringForRangeParameterizedAttribute as String: "h b" as NSString,
            ]
        )

        let reader = FocusedTextReader(provider: MockFocusedProvider(element: element))
        let session = try reader.captureSession(targetProcessIdentifier: 99)

        XCTAssertEqual(session.selectedText, "h b")
        XCTAssertEqual(session.readStrategy, .selectedTextRange)
    }

    func testWriteUsesSelectedTextAttributeWhenSettable() throws {
        let element = MockAXCapabilityElement(
            attributes: [
                kAXSelectedTextAttribute as String: "teh" as NSString,
            ],
            attributeNames: [
                kAXSelectedTextAttribute as String,
            ],
            settableAttributes: [
                kAXSelectedTextAttribute as String,
            ]
        )

        let session = makeSession(
            element: element,
            selectedText: "teh",
            writeStrategy: .selectedTextAttribute
        )

        let writer = FocusedTextWriter()
        try writer.replaceSelection(in: session, with: "the")

        XCTAssertEqual(element.lastSetAttribute, kAXSelectedTextAttribute as String)
        XCTAssertEqual(element.lastSetStringValue, "the")
    }

    func testWriteMutatesValueUsingSelectedRangeWhenSelectedTextIsNotSettable() throws {
        let element = MockAXCapabilityElement(
            attributes: [
                kAXValueAttribute as String: "hello teh world" as NSString,
            ],
            attributeNames: [
                kAXValueAttribute as String,
                kAXSelectedTextRangeAttribute as String,
            ],
            settableAttributes: [
                kAXValueAttribute as String,
            ]
        )

        let session = makeSession(
            element: element,
            selectedText: "teh",
            selectedRange: CFRange(location: 6, length: 3),
            fullValue: "hello teh world",
            writeStrategy: .valueAndSelectedTextRange
        )

        let writer = FocusedTextWriter()
        try writer.replaceSelection(in: session, with: "the")

        XCTAssertEqual(element.lastSetAttribute, kAXValueAttribute as String)
        XCTAssertEqual(element.lastSetStringValue, "hello the world")
    }

    func testReadReturnsSelectionWhenFocusedElementSupportsSelectedText() throws {
        let element = MockAXElement()
        element.attributes[kAXSelectedTextAttribute as String] = "selected" as NSString

        let reader = FocusedTextReader(provider: MockFocusedProvider(element: element))
        let selected = try reader.currentSelection()

        XCTAssertEqual(selected, "selected")
    }

    func testReadRetriesWhenFocusedElementIsTemporarilyUnavailable() throws {
        let element = MockAXElement()
        element.attributes[kAXSelectedTextAttribute as String] = "selected after retry" as NSString

        let reader = FocusedTextReader(
            provider: EventuallyFocusedProvider(elements: [nil, element]),
            maxReadAttempts: 2,
            readRetryDelayMicroseconds: 0
        )

        let selected = try reader.currentSelection()

        XCTAssertEqual(selected, "selected after retry")
    }

    func testWriteFailsWhenAXWriteFails() {
        let element = MockAXElement()
        element.nextWriteError = .cannotComplete

        let writer = FocusedTextWriter(provider: MockFocusedProvider(element: element))

        XCTAssertThrowsError(try writer.replaceSelection(with: "replacement"))
    }
}
