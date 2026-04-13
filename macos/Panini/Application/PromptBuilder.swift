import Foundation

struct PromptMessage: Equatable, Sendable {
    let role: String
    let content: String
}

struct PromptMessages: Equatable, Sendable {
    let system: PromptMessage
    let user: PromptMessage
    let preset: PromptPreset
}

struct PromptBuilder {
    func messages(
        text: String,
        presetID: String,
        model: LocalModel,
        dictionaryWords: [String],
        avoidOutputs: [String]
    ) throws -> PromptMessages {
        guard let preset = PromptPreset.preset(id: presetID) else {
            throw PaniniError.backendRequestFailed("Unknown prompt preset '\(presetID)'.")
        }

        let systemPrompt = model.supportsNoThink
            ? "/no_think\n\n\(preset.systemPrompt)"
            : preset.systemPrompt

        return PromptMessages(
            system: PromptMessage(role: "system", content: systemPrompt),
            user: PromptMessage(
                role: "user",
                content: buildUserMessage(
                    text: text,
                    dictionaryWords: dictionaryWords,
                    responseMode: preset.responseMode,
                    avoidOutputs: avoidOutputs
                )
            ),
            preset: preset
        )
    }

    private func buildUserMessage(
        text: String,
        dictionaryWords: [String],
        responseMode: PromptPreset.ResponseMode,
        avoidOutputs: [String]
    ) -> String {
        var parts: [String] = []

        if !dictionaryWords.isEmpty {
            parts.append(
                "These terms are correct and must never be changed: \(dictionaryWords.joined(separator: ", "))."
            )
        }

        switch responseMode {
        case .single:
            parts.append(
                "Return ONLY the corrected text. No explanations, no markdown, and no surrounding quotes. If the text is already correct, return it unchanged."
            )

        case let .variants(count):
            parts.append(
                "Return exactly \(count) options. Use tagged blocks in this format: [[option:recommended]]...[[/option]] for the best option and [[option:alternative]]...[[/option]] for the others. No explanations, no markdown outside the option blocks, and no surrounding quotes."
            )

            if !avoidOutputs.isEmpty {
                let previous = avoidOutputs.map { "- \($0)" }.joined(separator: "\n")
                parts.append("Do not repeat or lightly rephrase these previous options:\n\(previous)")
            }
        }

        parts.append("Text to correct:")
        parts.append(text)

        return parts.joined(separator: "\n")
    }
}
