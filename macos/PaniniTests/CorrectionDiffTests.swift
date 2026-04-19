import XCTest
@testable import GrammarAI

final class CorrectionDiffTests: XCTestCase {
    func testNoChanges() {
        XCTAssertEqual(CorrectionDiff.computeChanges(original: "hello world", corrected: "hello world"), [])
    }

    func testSingleWordReplacement() throws {
        let changes = CorrectionDiff.computeChanges(original: "i am here", corrected: "I am here")

        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(change.originalText, "i")
        XCTAssertEqual(change.replacement, "I")
        XCTAssertEqual(change.offsetStart, 0)
        XCTAssertEqual(change.offsetEnd, 1)
    }

    func testInsertionExpandsContext() throws {
        let changes = CorrectionDiff.computeChanges(
            original: "there more models",
            corrected: "there are more models"
        )

        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(change.originalText, "there more")
        XCTAssertEqual(change.replacement, "there are more")
    }

    func testDeletionExpandsContext() throws {
        let changes = CorrectionDiff.computeChanges(original: "I am am here", corrected: "I am here")

        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(change.originalText, "I am am")
        XCTAssertEqual(change.replacement, "I am")
    }

    func testMultipleChanges() throws {
        let changes = CorrectionDiff.computeChanges(
            original: "i think there more models are there",
            corrected: "I think there are more models are available"
        )

        XCTAssertGreaterThanOrEqual(changes.count, 2)
        XCTAssertEqual(changes[0].originalText, "i")
        XCTAssertEqual(changes[0].replacement, "I")
    }

    func testEmptyOriginal() {
        XCTAssertEqual(CorrectionDiff.computeChanges(original: "", corrected: ""), [])
    }

    func testAllDefaultCategoryIsGrammar() {
        let changes = CorrectionDiff.computeChanges(original: "i am", corrected: "I am")

        XCTAssertTrue(changes.allSatisfy { $0.category == .grammar })
    }

    func testChangeOffsetsAreValid() {
        let original = "i has a error in here"
        let corrected = "I have an error in here"
        let changes = CorrectionDiff.computeChanges(original: original, corrected: corrected)
        let nsOriginal = original as NSString

        for change in changes {
            XCTAssertGreaterThanOrEqual(change.offsetStart, 0)
            XCTAssertLessThanOrEqual(change.offsetStart, change.offsetEnd)
            XCTAssertLessThanOrEqual(change.offsetEnd, nsOriginal.length)

            let range = NSRange(location: change.offsetStart, length: change.offsetEnd - change.offsetStart)
            XCTAssertEqual(nsOriginal.substring(with: range), change.originalText)
        }
    }

    func testOffsetsUseUTF16UnitsForEmojiBeforeChange() throws {
        let changes = CorrectionDiff.computeChanges(original: "🙂 teh", corrected: "🙂 the")

        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(change.originalText, "teh")
        XCTAssertEqual(change.replacement, "the")
        XCTAssertEqual(change.offsetStart, 3)
        XCTAssertEqual(change.offsetEnd, 6)
    }

    func testPunctuationPreservedInReplacements() {
        let changes = CorrectionDiff.computeChanges(original: "Hello ,world", corrected: "Hello, world")

        XCTAssertGreaterThanOrEqual(changes.count, 1)
        XCTAssertTrue(changes.contains { $0.originalText.contains(",") || $0.replacement.contains(",") })
    }
}
