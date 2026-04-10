import XCTest
@testable import GrammarAI

final class UndoBufferTests: XCTestCase {
    func testUndoReturnsPreviousSelectionWithinWindow() {
        let buffer = UndoBuffer(ttlSeconds: 10)
        buffer.push(previousText: "before")

        let restored = buffer.popIfValid(now: Date().addingTimeInterval(5))
        XCTAssertEqual(restored, "before")
    }

    func testUndoReturnsNilAfterWindow() {
        let buffer = UndoBuffer(ttlSeconds: 1)
        buffer.push(previousText: "before")

        let restored = buffer.popIfValid(now: Date().addingTimeInterval(5))
        XCTAssertNil(restored)
    }
}
