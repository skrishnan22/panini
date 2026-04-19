import XCTest
@testable import GrammarAI

final class ThinkingTagStripperTests: XCTestCase {
    func testStripsEmptyThinkBlock() {
        let output = ThinkingTagStripper.strip("<think>\n\n</think>\nCorrected text.")

        XCTAssertEqual(output, "Corrected text.")
    }

    func testStripsNonEmptyThinkBlock() {
        let output = ThinkingTagStripper.strip("<think>I should fix grammar.</think>\nI have an error.")

        XCTAssertEqual(output, "I have an error.")
    }

    func testPreservesTextWithoutThinkBlock() {
        let output = ThinkingTagStripper.strip("I have an error.")

        XCTAssertEqual(output, "I have an error.")
    }

    func testTrimsOuterWhitespaceAfterStrip() {
        let output = ThinkingTagStripper.strip("  Hello <think>ignore me</think> world.  ")

        XCTAssertEqual(output, "Hello  world.")
    }
}
