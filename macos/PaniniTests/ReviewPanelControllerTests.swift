import AppKit
import XCTest
@testable import GrammarAI

final class ReviewPanelControllerTests: XCTestCase {
    @MainActor
    func testBuildPanelUsesNonActivatingConfigurationAndAvoidsKeyingThePanel() {
        let controller = ReviewPanelController()
        let panel = controller.makePanelForTesting()

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertEqual(panel.frame.size.width, 472)
        XCTAssertEqual(panel.frame.size.height, 332)
    }
}
