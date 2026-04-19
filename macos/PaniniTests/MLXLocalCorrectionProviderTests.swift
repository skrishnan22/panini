import XCTest
@testable import GrammarAI

final class MLXLocalCorrectionProviderTests: XCTestCase {
    func testSingleCorrectionUsesGeneratedTextAndComputesChanges() async throws {
        let generator = MockLocalTextGenerator(output: "I have an error.")
        let provider = MLXLocalCorrectionProvider(
            userSettings: makeSettings(),
            dictionaryStore: StubDictionaryStore(words: []),
            generator: generator
        )

        let result = try await provider.correct(text: "i has an error.", mode: .review, preset: "fix")

        XCTAssertEqual(result.original, "i has an error.")
        XCTAssertEqual(result.corrected, "I have an error.")
        XCTAssertFalse(result.changes.isEmpty)
        XCTAssertEqual(result.modelUsed, LocalModelCatalog.defaultModelID)
        XCTAssertEqual(result.backendUsed, "mlx")

        let request = await generator.lastRequest
        XCTAssertEqual(request?.model.id, LocalModelCatalog.defaultModelID)
        XCTAssertEqual(request?.maxTokens, 1024)
        XCTAssertFalse(request?.systemPrompt.hasPrefix("/no_think") == true)
    }

    func testSingleCorrectionStripsThinkingTags() async throws {
        let provider = MLXLocalCorrectionProvider(
            userSettings: makeSettings(),
            dictionaryStore: StubDictionaryStore(words: []),
            generator: MockLocalTextGenerator(output: "<think>\nchecking\n</think>\nI have an error.")
        )

        let result = try await provider.correct(text: "i has an error.", mode: .review, preset: "fix")

        XCTAssertEqual(result.corrected, "I have an error.")
    }

    func testSingleCorrectionAppliesUTF16Offsets() async throws {
        let provider = MLXLocalCorrectionProvider(
            userSettings: makeSettings(),
            dictionaryStore: StubDictionaryStore(words: []),
            generator: MockLocalTextGenerator(output: "🙂 the")
        )

        let result = try await provider.correct(text: "🙂 teh", mode: .review, preset: "fix")

        XCTAssertEqual(result.corrected, "🙂 the")
        XCTAssertEqual(result.changes.first?.offsetStart, 3)
    }

    func testVariantsParseGeneratedOptions() async throws {
        let provider = MLXLocalCorrectionProvider(
            userSettings: makeSettings(),
            dictionaryStore: StubDictionaryStore(words: []),
            generator: MockLocalTextGenerator(output: """
            [[option:recommended]]Can we meet today?[[/option]]
            [[option:alternative]]Are we able to meet today?[[/option]]
            """)
        )

        let response = try await provider.correct(
            text: "can we meet today",
            mode: .review,
            preset: "paraphrase",
            avoidOutputs: ["Could we meet today?"]
        )

        guard case let .variants(payload) = response else {
            return XCTFail("Expected variants")
        }

        XCTAssertEqual(payload.variants.map(\.text), [
            "Can we meet today?",
            "Are we able to meet today?"
        ])
        XCTAssertEqual(payload.modelUsed, LocalModelCatalog.defaultModelID)
        XCTAssertEqual(payload.backendUsed, "mlx")
    }

    func testDictionaryProtectedChangesAreNotAppliedOrPresented() async throws {
        let provider = MLXLocalCorrectionProvider(
            userSettings: makeSettings(),
            dictionaryStore: StubDictionaryStore(words: ["Paninii"]),
            generator: MockLocalTextGenerator(output: "Ask Panini today.")
        )

        let result = try await provider.correct(text: "Ask Paninii today.", mode: .review, preset: "fix")

        XCTAssertEqual(result.corrected, "Ask Paninii today.")
        XCTAssertEqual(result.changes, [])
    }

    func testUnknownSelectedModelThrows() async {
        let settings = makeSettings()
        settings.selectedModelID = "missing/model"
        let provider = MLXLocalCorrectionProvider(
            userSettings: settings,
            dictionaryStore: StubDictionaryStore(words: []),
            generator: MockLocalTextGenerator(output: "")
        )

        do {
            _ = try await provider.correct(text: "Hello", mode: .review, preset: "fix")
            XCTFail("Expected unknown model error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unknown local model 'missing/model'.")
        }
    }

    private func makeSettings() -> UserSettings {
        let suiteName = "MLXLocalCorrectionProviderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return UserSettings(defaults: defaults)
    }
}

private actor MockLocalTextGenerator: LocalTextGenerating {
    struct Request {
        let model: LocalModel
        let systemPrompt: String
        let userMessage: String
        let maxTokens: Int
        let temperature: Float
    }

    private let output: String
    private var requests: [Request] = []

    init(output: String) {
        self.output = output
    }

    var lastRequest: Request? {
        requests.last
    }

    func generate(
        model: LocalModel,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> String {
        requests.append(Request(
            model: model,
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: maxTokens,
            temperature: temperature
        ))
        return output
    }
}

private struct StubDictionaryStore: DictionaryManaging {
    let words: [String]

    func listWords() async throws -> [String] {
        words
    }

    func addWord(_ word: String) async throws {}

    func removeWord(_ word: String) async throws {}
}
