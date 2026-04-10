import ApplicationServices
import XCTest
@testable import GrammarAI

final class AXElementCapabilitiesTests: XCTestCase {
    func testSnapshotCapturesAttributesSettableFlagsAndParameterizedAttributes() {
        let element = MockAXCapabilityElement(
            attributes: [
                kAXSelectedTextAttribute as String: "draft" as NSString,
                kAXValueAttribute as String: "draft body" as NSString,
            ],
            attributeNames: [
                kAXSelectedTextAttribute as String,
                kAXValueAttribute as String,
                kAXSelectedTextRangeAttribute as String,
            ],
            parameterizedAttributeNames: [
                kAXStringForRangeParameterizedAttribute as String,
            ],
            settableAttributes: [
                kAXValueAttribute as String,
            ]
        )

        let snapshot = AXElementCapabilities.snapshot(from: element)

        XCTAssertTrue(snapshot.supportedAttributes.contains(kAXSelectedTextRangeAttribute as String))
        XCTAssertTrue(snapshot.supportedParameterizedAttributes.contains(kAXStringForRangeParameterizedAttribute as String))
        XCTAssertTrue(snapshot.settableAttributes.contains(kAXValueAttribute as String))
        XCTAssertFalse(snapshot.settableAttributes.contains(kAXSelectedTextAttribute as String))
    }
}
