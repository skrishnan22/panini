import XCTest
@testable import GrammarAI

@MainActor
final class ReviewSessionTests: XCTestCase {
    private func makeChanges() -> [Change] {
        [
            Change(offsetStart: 0, offsetEnd: 3, originalText: "bad", replacement: "good", category: .grammar),
            Change(offsetStart: 4, offsetEnd: 7, originalText: "txt", replacement: "text", category: .clarity)
        ]
    }

    private func makeResult(
        original: String = "bad txt",
        corrected: String = "good text",
        changes: [Change]? = nil
    ) -> CorrectionResult {
        CorrectionResult(
            original: original,
            corrected: corrected,
            changes: changes ?? makeChanges(),
            modelUsed: "gemma-4-e4b",
            backendUsed: "mlx"
        )
    }

    private func makeVariants() -> [RewriteVariant] {
        [
            RewriteVariant(id: "variant-1", label: "Recommended", text: "Hello.", isRecommended: true),
            RewriteVariant(id: "variant-2", label: "Alternative", text: "Hi there.", isRecommended: false),
        ]
    }

    func testReadyPreviewTextStillRespectsToggledChanges() throws {
        let session = ReviewSession(originalText: "bad txt")
        session.transitionToReady(result: makeResult())

        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.previewText, "good text")

        let firstChangeID = try XCTUnwrap(session.visibleChanges.first?.id)
        session.toggle(firstChangeID)
        XCTAssertEqual(session.previewText, "bad text")

        let secondChangeID = try XCTUnwrap(session.visibleChanges.last?.id)
        session.toggle(secondChangeID)
        XCTAssertEqual(session.previewText, "bad txt")
    }

    func testReadyPreviewTextAppliesUTF16Offsets() throws {
        let original = "🙂 teh"
        let corrected = "🙂 the"
        let changes = CorrectionDiff.computeChanges(original: original, corrected: corrected)
        let session = ReviewSession(originalText: original)

        session.transitionToReady(result: makeResult(
            original: original,
            corrected: corrected,
            changes: changes
        ))

        XCTAssertEqual(session.previewText, corrected)
    }

    func testEmptyStateReturnsOriginalTextAndDisallowsApply() {
        let session = ReviewSession(originalText: "Looks fine already")

        session.transitionToEmpty()

        XCTAssertEqual(session.phase, .empty)
        XCTAssertEqual(session.previewText, "Looks fine already")
        XCTAssertEqual(session.visibleChanges, [])
        XCTAssertFalse(session.canApply)
        XCTAssertTrue(session.canCopy)
    }

    func testFailedStateExposesNoChangesAndNoCopyOrApply() {
        let session = ReviewSession(originalText: "bad txt")
        session.transitionToReady(result: makeResult())

        session.transitionToFailure("Backend returned status 500.")

        XCTAssertEqual(session.phase, .failed(message: "Backend returned status 500."))
        XCTAssertEqual(session.visibleChanges, [])
        XCTAssertFalse(session.canApply)
        XCTAssertFalse(session.canCopy)
        XCTAssertFalse(session.showsChangeList)
    }

    func testTransitionToReadyResetsDisabledChangeIDs() throws {
        let session = ReviewSession(originalText: "bad txt")
        session.transitionToReady(result: makeResult())

        let changeID = try XCTUnwrap(session.visibleChanges.first?.id)
        session.toggle(changeID)
        XCTAssertEqual(session.disabledChangeIDs, [changeID])

        session.transitionToLoading()
        session.transitionToReady(result: makeResult())

        XCTAssertTrue(session.disabledChangeIDs.isEmpty)
        XCTAssertEqual(session.previewText, "good text")
    }

    func testVariantSessionSelectsRecommendedOptionByDefault() {
        let session = ReviewSession(originalText: "hey")

        session.transitionToVariants(
            action: .paraphrase,
            variants: makeVariants()
        )

        XCTAssertEqual(session.previewText, "Hello.")
        XCTAssertTrue(session.canRegenerate)
    }

    func testSelectingVariantUpdatesPreviewText() {
        let session = ReviewSession(originalText: "hey")
        session.transitionToVariants(
            action: .paraphrase,
            variants: makeVariants()
        )

        session.selectVariant(id: "variant-2")

        XCTAssertEqual(session.previewText, "Hi there.")
    }

    func testVariantSessionHeaderReflectsSingleVisibleSuggestion() {
        let session = ReviewSession(originalText: "hey")

        session.transitionToVariants(
            action: .paraphrase,
            variants: makeVariants()
        )

        XCTAssertEqual(session.changeCountLabel, "1 suggestion")
    }
}
