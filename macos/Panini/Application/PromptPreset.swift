import Foundation

struct PromptPreset: Equatable, Sendable {
    enum ResponseMode: Equatable, Sendable {
        case single
        case variants(count: Int)
    }

    let id: String
    let name: String
    let description: String
    let systemPrompt: String
    let temperature: Float
    let responseMode: ResponseMode

    static let all: [PromptPreset] = [
        PromptPreset(
            id: "fix",
            name: "Fix",
            description: "Spelling and grammar only. Minimal changes.",
            systemPrompt: "You are a grammar checker. Fix spelling, grammar, sentence capitalization, proper noun capitalization, and punctuation errors in the user's text. Do not rewrite wording, style, tone, or meaning. Return ONLY the corrected text with no explanation.",
            temperature: 0.1,
            responseMode: .single
        ),
        PromptPreset(
            id: "improve",
            name: "Improve",
            description: "Fix grammar plus improve clarity and conciseness.",
            systemPrompt: "You are a writing assistant. Fix spelling and grammar errors, then improve clarity and conciseness. Remove unnecessary words. Do not change the meaning. Return exactly the requested tagged option blocks and nothing else.",
            temperature: 0.3,
            responseMode: .variants(count: 2)
        ),
        PromptPreset(
            id: "professional",
            name: "Professional",
            description: "Fix grammar and adjust to formal, professional tone.",
            systemPrompt: "You are a professional writing assistant. Fix spelling and grammar errors, then adjust the tone to be formal and professional, suitable for business emails and documents. Preserve the meaning. Return exactly the requested tagged option blocks and nothing else.",
            temperature: 0.3,
            responseMode: .variants(count: 2)
        ),
        PromptPreset(
            id: "casual",
            name: "Casual",
            description: "Fix grammar and simplify to a relaxed, conversational tone.",
            systemPrompt: "You are a writing assistant. Fix spelling and grammar errors, then simplify the language to be casual and conversational. Keep it natural and easy to read. Return exactly the requested tagged option blocks and nothing else.",
            temperature: 0.4,
            responseMode: .variants(count: 2)
        ),
        PromptPreset(
            id: "paraphrase",
            name: "Paraphrase",
            description: "Rewrite the text with the same meaning using different wording.",
            systemPrompt: "You are a writing assistant. Rewrite the user's text with the same meaning, natural phrasing, and no added facts. Return exactly the requested tagged option blocks and nothing else.",
            temperature: 0.5,
            responseMode: .variants(count: 2)
        ),
    ]

    static func preset(id: String) -> PromptPreset? {
        all.first { $0.id == id }
    }
}
