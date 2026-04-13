import Foundation

struct MLXLocalCorrectionProvider: CorrectionServing {
    private let userSettings: UserSettings
    private let dictionaryStore: DictionaryManaging
    private let generator: LocalTextGenerating
    private let promptBuilder: PromptBuilder
    private let variantParser: VariantResponseParser
    private let maxTokens: Int

    init(
        userSettings: UserSettings,
        dictionaryStore: DictionaryManaging,
        generator: LocalTextGenerating,
        promptBuilder: PromptBuilder = PromptBuilder(),
        variantParser: VariantResponseParser = VariantResponseParser(),
        maxTokens: Int = 1024
    ) {
        self.userSettings = userSettings
        self.dictionaryStore = dictionaryStore
        self.generator = generator
        self.promptBuilder = promptBuilder
        self.variantParser = variantParser
        self.maxTokens = maxTokens
    }

    func prepare() async throws {
        _ = try selectedModel()
    }

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        let response = try await correct(text: text, mode: mode, preset: preset, avoidOutputs: [])
        guard case let .single(result) = response else {
            throw PaniniError.backendRequestFailed("Expected a single correction payload.")
        }
        return result
    }

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PaniniError.selectionUnavailable
        }

        let model = try selectedModel()
        let dictionaryWords = try await dictionaryStore.listWords()
        let messages = try promptBuilder.messages(
            text: text,
            presetID: preset,
            model: model,
            dictionaryWords: dictionaryWords,
            avoidOutputs: avoidOutputs
        )

        let generated = try await generator.generate(
            model: model,
            systemPrompt: messages.system.content,
            userMessage: messages.user.content,
            maxTokens: maxTokens,
            temperature: messages.preset.temperature
        )
        let output = ThinkingTagStripper.strip(generated)

        switch messages.preset.responseMode {
        case .single:
            return .single(singlePayload(
                original: text,
                corrected: output,
                model: model,
                dictionaryWords: dictionaryWords
            ))

        case let .variants(count):
            return .variants(VariantCorrectionPayload(
                original: text,
                variants: variantParser.parse(output, expectedCount: count),
                modelUsed: model.id,
                backendUsed: "mlx"
            ))
        }
    }

    private func selectedModel() throws -> LocalModel {
        let modelID = userSettings.selectedModelID
        guard let model = LocalModelCatalog.model(id: modelID) else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }
        return model
    }

    private func singlePayload(
        original: String,
        corrected: String,
        model: LocalModel,
        dictionaryWords: [String]
    ) -> CorrectionResult {
        let changes = CorrectionDiff.computeChanges(original: original, corrected: corrected)
        let filteredChanges = changes.filter { !isProtected(change: $0, in: original, dictionaryWords: dictionaryWords) }
        let filteredCorrected = apply(changes: filteredChanges, to: original)

        return CorrectionResult(
            original: original,
            corrected: filteredCorrected,
            changes: filteredChanges,
            modelUsed: model.id,
            backendUsed: "mlx"
        )
    }

    private func isProtected(change: Change, in original: String, dictionaryWords: [String]) -> Bool {
        dictionaryWords.contains { word in
            guard !word.isEmpty else { return false }
            if change.originalText.contains(word) || change.replacement.contains(word) {
                return true
            }
            return ranges(of: word, in: original).contains { range in
                range.overlaps(change.offsetStart..<change.offsetEnd)
            }
        }
    }

    private func ranges(of word: String, in text: String) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let range = text.range(of: word, range: searchStart..<text.endIndex)
        {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            ranges.append(start..<end)
            searchStart = range.upperBound
        }

        return ranges
    }

    private func apply(changes: [Change], to original: String) -> String {
        changes
            .sorted { $0.offsetStart > $1.offsetStart }
            .reduce(original) { current, change in
                guard change.offsetStart >= 0,
                      change.offsetEnd >= change.offsetStart,
                      change.offsetEnd <= current.count
                else {
                    return current
                }

                let lower = current.index(current.startIndex, offsetBy: change.offsetStart)
                let upper = current.index(current.startIndex, offsetBy: change.offsetEnd)
                var next = current
                next.replaceSubrange(lower..<upper, with: change.replacement)
                return next
            }
    }
}
