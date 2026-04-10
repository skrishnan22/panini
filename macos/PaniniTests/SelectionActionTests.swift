import XCTest
@testable import GrammarAI

final class SelectionActionTests: XCTestCase {
    func testParaphraseActionUsesVariantPresentation() {
        XCTAssertEqual(SelectionAction.paraphrase.presetID, "paraphrase")
        XCTAssertEqual(SelectionAction.paraphrase.reviewStyle, .rewriteVariants)
        XCTAssertEqual(SelectionAction.fix.reviewStyle, .singleCorrection)
    }
}
