import XCTest
@testable import GrammarAI

@MainActor
final class ActionPaletteSessionTests: XCTestCase {
    func testDefaultOrderingPrioritizesFixThenParaphrase() {
        let session = ActionPaletteSession(actions: SelectionAction.allCases)

        XCTAssertEqual(session.visibleActions, [.fix, .paraphrase, .professional, .improve, .casual])
        XCTAssertEqual(session.highlightedAction, .fix)
    }

    func testMoveSelectionWrapsAround() {
        let session = ActionPaletteSession(actions: [.fix, .paraphrase, .professional])

        session.moveSelection(by: -1)

        XCTAssertEqual(session.highlightedAction, .professional)
    }
}
