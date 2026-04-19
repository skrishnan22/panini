import AppKit
import XCTest
@testable import GrammarAI

final class PasteboardSnapshotTests: XCTestCase {
    func testRestoresMultipleItemsAndTypes() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PaniniTests-\(UUID().uuidString)"))
        let customType = NSPasteboard.PasteboardType("com.panini.tests.custom")
        let customData = Data([0x70, 0x61, 0x6e, 0x69, 0x6e, 0x69])

        pasteboard.clearContents()
        defer { pasteboard.clearContents() }

        let firstItem = NSPasteboardItem()
        firstItem.setString("plain text", forType: .string)
        firstItem.setData(customData, forType: customType)

        let secondItem = NSPasteboardItem()
        secondItem.setString("second item", forType: .string)

        XCTAssertTrue(pasteboard.writeObjects([firstItem, secondItem]))

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("replacement", forType: .string)

        snapshot.restore(to: pasteboard)

        let restoredItems = pasteboard.pasteboardItems ?? []
        XCTAssertEqual(restoredItems.count, 2)
        XCTAssertEqual(restoredItems[0].string(forType: .string), "plain text")
        XCTAssertEqual(restoredItems[0].data(forType: customType), customData)
        XCTAssertEqual(restoredItems[1].string(forType: .string), "second item")
    }
}
