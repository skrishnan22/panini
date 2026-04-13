import XCTest
@testable import GrammarAI

final class PromptBuilderTests: XCTestCase {
    func testBuildsSingleCorrectionMessages() throws {
        let messages = try PromptBuilder().messages(
            text: "i has a error",
            presetID: "fix",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: [],
            avoidOutputs: []
        )

        XCTAssertEqual(messages.system.role, "system")
        XCTAssertEqual(messages.user.role, "user")
        XCTAssertTrue(messages.system.content.contains("grammar checker"))
        XCTAssertTrue(messages.user.content.contains("Return ONLY the corrected text"))
        XCTAssertTrue(messages.user.content.contains("i has a error"))
        XCTAssertEqual(messages.preset.temperature, 0.1)
    }

    func testFixPresetExplicitlyIncludesCapitalizationAndPunctuation() throws {
        let messages = try PromptBuilder().messages(
            text: "got invoice from stripe",
            presetID: "fix",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: [],
            avoidOutputs: []
        )

        XCTAssertTrue(messages.system.content.contains("sentence capitalization"))
        XCTAssertTrue(messages.system.content.contains("proper noun capitalization"))
        XCTAssertTrue(messages.system.content.contains("punctuation errors"))
    }

    func testVariantPromptRequestsExactOptions() throws {
        let messages = try PromptBuilder().messages(
            text: "Can you send me the file?",
            presetID: "paraphrase",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: [],
            avoidOutputs: []
        )

        XCTAssertTrue(messages.user.content.contains("Return exactly 2 options"))
        XCTAssertTrue(messages.user.content.contains("[[option:recommended]]"))
        XCTAssertTrue(messages.user.content.contains("[[/option]]"))
        XCTAssertEqual(messages.preset.responseMode, .variants(count: 2))
    }

    func testDictionaryWordsIncludedInPrompt() throws {
        let messages = try PromptBuilder().messages(
            text: "Use MLX for inference",
            presetID: "fix",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: ["MLX"],
            avoidOutputs: []
        )

        XCTAssertTrue(messages.user.content.contains("These terms are correct"))
        XCTAssertTrue(messages.user.content.contains("MLX"))
    }

    func testVariantPromptIncludesAvoidOutputs() throws {
        let messages = try PromptBuilder().messages(
            text: "hey checking in",
            presetID: "professional",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: [],
            avoidOutputs: ["Hello, I am following up."]
        )

        XCTAssertTrue(messages.user.content.contains("Do not repeat or lightly rephrase"))
        XCTAssertTrue(messages.user.content.contains("- Hello, I am following up."))
    }

    func testDefaultQwen25ModelDoesNotGetNoThinkPrefix() throws {
        let messages = try PromptBuilder().messages(
            text: "hello",
            presetID: "fix",
            model: LocalModelCatalog.defaultModel,
            dictionaryWords: [],
            avoidOutputs: []
        )

        XCTAssertFalse(messages.system.content.hasPrefix("/no_think\n\n"))
    }

    func testQwen3ModelGetsNoThinkPrefix() throws {
        let model = try XCTUnwrap(LocalModelCatalog.model(id: "mlx-community/Qwen3-4B-4bit"))
        let messages = try PromptBuilder().messages(
            text: "hello",
            presetID: "fix",
            model: model,
            dictionaryWords: [],
            avoidOutputs: []
        )

        XCTAssertTrue(messages.system.content.hasPrefix("/no_think\n\n"))
    }
}
