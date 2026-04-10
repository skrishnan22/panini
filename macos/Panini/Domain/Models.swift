import Foundation

public enum ChangeCategory: String, Codable, CaseIterable, Sendable {
    case spelling
    case grammar
    case clarity
    case tone
    case style
}

public struct Change: Codable, Equatable, Sendable {
    public let offsetStart: Int
    public let offsetEnd: Int
    public let originalText: String
    public let replacement: String
    public let category: ChangeCategory

    enum CodingKeys: String, CodingKey {
        case offsetStart = "offset_start"
        case offsetEnd = "offset_end"
        case originalText = "original_text"
        case replacement
        case category
    }

    public init(
        offsetStart: Int,
        offsetEnd: Int,
        originalText: String,
        replacement: String,
        category: ChangeCategory
    ) {
        self.offsetStart = offsetStart
        self.offsetEnd = offsetEnd
        self.originalText = originalText
        self.replacement = replacement
        self.category = category
    }
}

public struct CorrectionResult: Codable, Equatable, Sendable {
    public let original: String
    public let corrected: String
    public let changes: [Change]
    public let modelUsed: String
    public let backendUsed: String

    enum CodingKeys: String, CodingKey {
        case original
        case corrected
        case changes
        case modelUsed = "model_used"
        case backendUsed = "backend_used"
    }

    public init(
        original: String,
        corrected: String,
        changes: [Change],
        modelUsed: String,
        backendUsed: String
    ) {
        self.original = original
        self.corrected = corrected
        self.changes = changes
        self.modelUsed = modelUsed
        self.backendUsed = backendUsed
    }
}

public typealias SingleCorrectionPayload = CorrectionResult

public struct RewriteVariant: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let label: String
    public let text: String
    public let isRecommended: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case text
        case isRecommended = "is_recommended"
    }
}

public struct VariantCorrectionPayload: Codable, Equatable, Sendable {
    public let original: String
    public let variants: [RewriteVariant]
    public let modelUsed: String
    public let backendUsed: String

    enum CodingKeys: String, CodingKey {
        case original
        case variants
        case modelUsed = "model_used"
        case backendUsed = "backend_used"
    }
}

public enum CorrectionResponse: Equatable, Sendable {
    case single(SingleCorrectionPayload)
    case variants(VariantCorrectionPayload)
}

public struct ReviewChange: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let change: Change

    public init(id: UUID = UUID(), change: Change) {
        self.id = id
        self.change = change
    }
}
