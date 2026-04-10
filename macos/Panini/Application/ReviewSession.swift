import Foundation
import Combine

@MainActor
final class ReviewSession: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case empty
        case failed(message: String)
    }

    enum Content: Equatable {
        case single(correctedText: String, changes: [ReviewChange])
        case variants(action: SelectionAction, variants: [RewriteVariant], selectedVariantID: String)
    }

    struct PreviewSegment: Equatable, Sendable {
        let text: String
        let isHighlighted: Bool
    }

    let originalText: String
    let targetProcessIdentifier: pid_t?
    let editingSession: TextEditingSession?

    @Published private(set) var phase: Phase
    @Published private(set) var content: Content?
    @Published private(set) var activeAction: SelectionAction?
    @Published var disabledChangeIDs: Set<UUID> = []

    init(
        originalText: String,
        targetProcessIdentifier: pid_t? = nil,
        editingSession: TextEditingSession? = nil,
        phase: Phase = .loading,
        content: Content? = nil,
        activeAction: SelectionAction? = nil
    ) {
        self.originalText = originalText
        self.targetProcessIdentifier = targetProcessIdentifier
        self.editingSession = editingSession
        self.phase = phase
        self.content = content
        self.activeAction = activeAction
    }

    convenience init(result: CorrectionResult, targetProcessIdentifier: pid_t? = nil, editingSession: TextEditingSession? = nil) {
        self.init(
            originalText: result.original,
            targetProcessIdentifier: targetProcessIdentifier,
            editingSession: editingSession
        )
        transitionToReady(result: result)
    }

    func toggle(_ changeID: UUID) {
        guard phase == .ready, changes.contains(where: { $0.id == changeID }) else { return }

        if disabledChangeIDs.contains(changeID) {
            disabledChangeIDs.remove(changeID)
        } else {
            disabledChangeIDs.insert(changeID)
        }
    }

    func transitionToLoading(action: SelectionAction? = nil) {
        phase = .loading
        content = nil
        if let action {
            activeAction = action
        }
        resetDisabledChanges()
    }

    func transitionToReady(result: CorrectionResult, action: SelectionAction? = nil) {
        guard !result.changes.isEmpty else {
            transitionToEmpty(action: action)
            return
        }

        phase = .ready
        content = .single(
            correctedText: result.corrected,
            changes: result.changes.map { ReviewChange(change: $0) }
        )
        if let action {
            activeAction = action
        }
        resetDisabledChanges()
    }

    func transitionToVariants(action: SelectionAction, variants: [RewriteVariant]) {
        guard !variants.isEmpty else {
            transitionToEmpty(action: action)
            return
        }

        let selectedVariantID = variants.first(where: \.isRecommended)?.id ?? variants[0].id

        phase = .ready
        content = .variants(action: action, variants: variants, selectedVariantID: selectedVariantID)
        activeAction = action
        resetDisabledChanges()
    }

    func selectVariant(id: String) {
        guard phase == .ready else { return }
        guard case let .variants(action, variants, _) = content else { return }
        guard variants.contains(where: { $0.id == id }) else { return }
        content = .variants(action: action, variants: variants, selectedVariantID: id)
    }

    func transitionToEmpty(action: SelectionAction? = nil) {
        phase = .empty
        content = nil
        if let action {
            activeAction = action
        }
        resetDisabledChanges()
    }

    func transitionToFailure(_ message: String, action: SelectionAction? = nil) {
        phase = .failed(message: message)
        content = nil
        if let action {
            activeAction = action
        }
        resetDisabledChanges()
    }

    func resetDisabledChanges() {
        disabledChangeIDs = []
    }

    var previewText: String {
        guard phase == .ready else { return originalText }

        switch content {
        case let .single(_, changes):
            let enabledChanges = changes.filter { !disabledChangeIDs.contains($0.id) }.map(\.change)
            if enabledChanges.isEmpty {
                return originalText
            }
            return Self.apply(changes: enabledChanges, to: originalText)
        case let .variants(_, variants, selectedVariantID):
            return variants.first(where: { $0.id == selectedVariantID })?.text ?? originalText
        case nil:
            return originalText
        }
    }

    var previewSegments: [PreviewSegment] {
        guard phase == .ready else {
            return [PreviewSegment(text: originalText, isHighlighted: false)]
        }

        switch content {
        case let .single(_, singleChanges):
            let enabledChanges = singleChanges.filter { !disabledChangeIDs.contains($0.id) }.map(\.change)
            guard !enabledChanges.isEmpty else {
                return [PreviewSegment(text: originalText, isHighlighted: false)]
            }

            let sorted = Self.sorted(changes: enabledChanges)
            let nsOriginal = originalText as NSString
            let length = nsOriginal.length

            var segments: [PreviewSegment] = []
            var cursor = 0

            for change in sorted {
                let start = max(0, min(length, change.offsetStart))
                let end = max(start, min(length, change.offsetEnd))
                if start < cursor {
                    continue
                }

                if start > cursor {
                    let untouchedRange = NSRange(location: cursor, length: start - cursor)
                    segments.append(
                        PreviewSegment(
                            text: nsOriginal.substring(with: untouchedRange),
                            isHighlighted: false
                        )
                    )
                }

                if !change.replacement.isEmpty {
                    segments.append(PreviewSegment(text: change.replacement, isHighlighted: true))
                }
                cursor = end
            }

            if cursor < length {
                let tail = NSRange(location: cursor, length: length - cursor)
                segments.append(
                    PreviewSegment(
                        text: nsOriginal.substring(with: tail),
                        isHighlighted: false
                    )
                )
            }

            return Self.merged(segments: segments)
        case .variants:
            return [PreviewSegment(text: previewText, isHighlighted: false)]
        case nil:
            return [PreviewSegment(text: originalText, isHighlighted: false)]
        }
    }

    var visibleChanges: [ReviewChange] {
        guard phase == .ready else { return [] }
        guard case let .single(_, changes) = content else { return [] }
        return changes
    }

    var changeCount: Int {
        switch content {
        case let .single(_, changes):
            return changes.count
        case let .variants(_, variants, _):
            return variants.count
        case nil:
            return 0
        }
    }

    var changeCountLabel: String {
        switch phase {
        case .loading:
            return "Reviewing…"
        case .ready:
            if case .variants = content {
                return "1 suggestion"
            }
            return changeCount == 1 ? "1 change" : "\(changeCount) changes"
        case .empty:
            return "Looks good"
        case .failed:
            return "Review failed"
        }
    }

    var canApply: Bool {
        phase == .ready
    }

    var canCopy: Bool {
        switch phase {
        case .ready, .empty:
            return true
        case .loading, .failed:
            return false
        }
    }

    var showsChangeList: Bool {
        !visibleChanges.isEmpty
    }

    var canRegenerate: Bool {
        phase == .ready && activeAction?.reviewStyle == .rewriteVariants && !currentVariantTexts.isEmpty
    }

    var currentVariantTexts: [String] {
        guard case let .variants(_, variants, _) = content else { return [] }
        return variants.map(\.text)
    }

    var changeSummaryText: String {
        guard phase == .ready else { return "" }

        if changeCount == 1, let change = visibleChanges.first?.change {
            return Self.summary(for: change.category)
        }

        let categories = Set(visibleChanges.map(\.change.category))
        if categories.count == 1, let category = categories.first {
            switch category {
            case .clarity:
                return "\(changeCount) wording refinements ready to review"
            case .grammar:
                return "\(changeCount) grammar fixes ready to review"
            case .spelling:
                return "\(changeCount) spelling fixes ready to review"
            case .tone:
                return "\(changeCount) tone edits ready to review"
            case .style:
                return "\(changeCount) style edits ready to review"
            }
        }

        return "\(changeCount) suggested edits ready to review"
    }

    var statusTitle: String {
        switch phase {
        case .loading, .ready:
            return activeAction?.reviewStyle == .rewriteVariants ? "Suggested rewrites" : "Suggested text"
        case .empty:
            return "Looks good"
        case .failed:
            return "Couldn't review text"
        }
    }

    var statusSubtitle: String {
        switch phase {
        case .loading:
            return activeAction?.reviewStyle == .rewriteVariants
                ? "Generating rewrite options"
                : "Checking grammar and phrasing"
        case .ready:
            return changeCountLabel
        case .empty:
            return "No edits needed right now."
        case let .failed(message):
            return message
        }
    }

    private static func apply(changes: [Change], to original: String) -> String {
        let sorted = sorted(changes: changes)

        let nsOriginal = original as NSString
        let length = nsOriginal.length

        var result = ""
        var cursor = 0

        for change in sorted {
            let start = max(0, min(length, change.offsetStart))
            let end = max(start, min(length, change.offsetEnd))
            if start < cursor {
                continue
            }

            if start > cursor {
                let untouchedRange = NSRange(location: cursor, length: start - cursor)
                result += nsOriginal.substring(with: untouchedRange)
            }

            result += change.replacement
            cursor = end
        }

        if cursor < length {
            let tail = NSRange(location: cursor, length: length - cursor)
            result += nsOriginal.substring(with: tail)
        }

        return result
    }

    private var changes: [ReviewChange] {
        guard case let .single(_, changes) = content else { return [] }
        return changes
    }

    private static func sorted(changes: [Change]) -> [Change] {
        changes.sorted { lhs, rhs in
            if lhs.offsetStart == rhs.offsetStart {
                return lhs.offsetEnd < rhs.offsetEnd
            }
            return lhs.offsetStart < rhs.offsetStart
        }
    }

    private static func merged(segments: [PreviewSegment]) -> [PreviewSegment] {
        var merged: [PreviewSegment] = []

        for segment in segments where !segment.text.isEmpty {
            if let last = merged.last, last.isHighlighted == segment.isHighlighted {
                merged[merged.count - 1] = PreviewSegment(
                    text: last.text + segment.text,
                    isHighlighted: last.isHighlighted
                )
            } else {
                merged.append(segment)
            }
        }

        return merged
    }

    private static func summary(for category: ChangeCategory) -> String {
        switch category {
        case .spelling:
            return "Spelling fix applied"
        case .grammar:
            return "Grammar fix applied"
        case .clarity:
            return "Wording fix applied for readability"
        case .tone:
            return "Tone adjustment applied"
        case .style:
            return "Style polish applied"
        }
    }
}
