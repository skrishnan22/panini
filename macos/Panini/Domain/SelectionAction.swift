import Foundation

enum ReviewStyle: Equatable, Sendable {
    case singleCorrection
    case rewriteVariants
}

enum SelectionAction: String, CaseIterable, Sendable {
    case fix
    case paraphrase
    case professional
    case improve
    case casual

    var presetID: String { rawValue }

    var title: String {
        switch self {
        case .fix:
            return "Fix"
        case .paraphrase:
            return "Paraphrase"
        case .professional:
            return "Professional"
        case .improve:
            return "Improve"
        case .casual:
            return "Casual"
        }
    }

    var subtitle: String {
        switch self {
        case .fix:
            return "Correct grammar and spelling"
        case .paraphrase:
            return "Generate rewrite variants"
        case .professional:
            return "Rewrite in a professional tone"
        case .improve:
            return "Polish clarity and flow"
        case .casual:
            return "Make the tone more casual"
        }
    }

    var reviewStyle: ReviewStyle {
        switch self {
        case .paraphrase, .professional, .improve, .casual:
            return .rewriteVariants
        case .fix:
            return .singleCorrection
        }
    }

    var directShortcutLabel: String? {
        switch self {
        case .fix:
            return "Default"
        case .paraphrase, .professional, .improve, .casual:
            return nil
        }
    }
}
