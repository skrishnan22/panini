import XCTest
@testable import GrammarAI

final class VariantResponseParserTests: XCTestCase {
    func testParsesTaggedRecommendedAndAlternative() {
        let raw = """
        [[option:recommended]]
        Please send me the file when you have a moment.
        [[/option]]
        [[option:alternative]]
        Could you send the file over when convenient?
        [[/option]]
        """

        let variants = VariantResponseParser().parse(raw, expectedCount: 2)

        XCTAssertEqual(variants.map(\.label), ["Recommended", "Alternative"])
        XCTAssertEqual(variants.map(\.isRecommended), [true, false])
        XCTAssertEqual(variants[0].text, "Please send me the file when you have a moment.")
        XCTAssertEqual(variants[1].id, "variant-2")
    }

    func testFallsBackToRawResponse() {
        let variants = VariantResponseParser().parse(
            "Please send me the file when you have a moment.",
            expectedCount: 2
        )

        XCTAssertEqual(variants.count, 1)
        XCTAssertEqual(variants[0].label, "Recommended")
        XCTAssertTrue(variants[0].isRecommended)
        XCTAssertEqual(variants[0].text, "Please send me the file when you have a moment.")
    }

    func testDedupesPreservingOrder() {
        let raw = """
        [[option:recommended]]
        Please send me the file when you have a moment.
        [[/option]]
        [[option:recommended]]
        Please send me the file when you have a moment.
        [[/option]]
        [[option:alternative]]
        Could you send the file over when convenient?
        [[/option]]
        """

        let variants = VariantResponseParser().parse(raw, expectedCount: 3)

        XCTAssertEqual(variants.map(\.text), [
            "Please send me the file when you have a moment.",
            "Could you send the file over when convenient?",
        ])
    }

    func testLimitsToExpectedCount() {
        let raw = """
        [[option:recommended]]One[[/option]]
        [[option:alternative]]Two[[/option]]
        [[option:alternative]]Three[[/option]]
        """

        let variants = VariantResponseParser().parse(raw, expectedCount: 2)

        XCTAssertEqual(variants.map(\.text), ["One", "Two"])
    }

    func testLabelsMultipleAlternatives() {
        let raw = """
        [option:alternative]One[/option]
        [option:alternative]Two[/option]
        [option:recommended]Three[/option]
        """

        let variants = VariantResponseParser().parse(raw, expectedCount: 3)

        XCTAssertEqual(variants.map(\.label), ["Alternative", "Alternative 2", "Recommended"])
        XCTAssertEqual(variants.map(\.isRecommended), [false, false, true])
    }
}
