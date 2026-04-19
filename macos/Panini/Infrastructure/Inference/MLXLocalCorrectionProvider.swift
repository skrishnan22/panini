import Foundation

struct MLXLocalCorrectionProvider: CorrectionServing {
    private let userSettings: UserSettings
    private let dictionaryStore: DictionaryManaging
    private let generator: LocalTextGenerating
    private let readinessChecker: LocalModelReadinessChecking?
    private let promptBuilder: PromptBuilder
    private let variantParser: VariantResponseParser
    private let maxTokens: Int

    init(
        userSettings: UserSettings,
        dictionaryStore: DictionaryManaging,
        generator: LocalTextGenerating,
        readinessChecker: LocalModelReadinessChecking? = nil,
        promptBuilder: PromptBuilder = PromptBuilder(),
        variantParser: VariantResponseParser = VariantResponseParser(),
        maxTokens: Int = 1024
    ) {
        self.userSettings = userSettings
        self.dictionaryStore = dictionaryStore
        self.generator = generator
        self.readinessChecker = readinessChecker
        self.promptBuilder = promptBuilder
        self.variantParser = variantParser
        self.maxTokens = maxTokens
    }

    func prepare() async throws {
        try await ensureModelReady(try selectedModel())
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
        try await ensureModelReady(model)
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

    private func ensureModelReady(_ model: LocalModel) async throws {
        guard let readinessChecker else { return }
        guard await readinessChecker.isModelReady(model.id) else {
            throw PaniniError.backendRequestFailed("Download a local model before using Panini.")
        }
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
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let match = nsText.range(of: word, options: [], range: searchRange)
            guard match.location != NSNotFound else { break }

            let start = match.location
            let end = NSMaxRange(match)
            ranges.append(start..<end)

            let nextLocation = end
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return ranges
    }

    private func apply(changes: [Change], to original: String) -> String {
        let current = NSMutableString(string: original)

        for change in changes.sorted(by: { $0.offsetStart > $1.offsetStart }) {
            guard change.offsetStart >= 0,
                  change.offsetEnd >= change.offsetStart,
                  change.offsetEnd <= current.length
            else {
                continue
            }

            current.replaceCharacters(
                in: NSRange(location: change.offsetStart, length: change.offsetEnd - change.offsetStart),
                with: change.replacement
            )
        }

        return current as String
    }
}
