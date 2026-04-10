import Combine
import Foundation

@MainActor
final class ActionPaletteSession: ObservableObject {
    private static let preferredOrdering: [SelectionAction] = [
        .fix,
        .paraphrase,
        .professional,
        .improve,
        .casual
    ]

    let visibleActions: [SelectionAction]

    @Published private(set) var highlightedIndex: Int

    init(actions: [SelectionAction], initialAction: SelectionAction = .fix) {
        let uniqueActions = actions.reduce(into: [SelectionAction]()) { result, action in
            if !result.contains(action) {
                result.append(action)
            }
        }
        let prioritized = Self.preferredOrdering.filter(uniqueActions.contains)
        let remaining = uniqueActions.filter { !prioritized.contains($0) }
        let orderedActions = prioritized + remaining

        precondition(!orderedActions.isEmpty, "ActionPaletteSession requires at least one action")

        visibleActions = orderedActions
        highlightedIndex = orderedActions.firstIndex(of: initialAction) ?? 0
    }

    var highlightedAction: SelectionAction {
        visibleActions[highlightedIndex]
    }

    func moveSelection(by delta: Int) {
        guard !visibleActions.isEmpty, delta != 0 else { return }

        let count = visibleActions.count
        highlightedIndex = (highlightedIndex + delta).positiveModulo(count)
    }

    func highlight(_ action: SelectionAction) {
        guard let index = visibleActions.firstIndex(of: action) else { return }
        highlightedIndex = index
    }
}

private extension Int {
    func positiveModulo(_ modulus: Int) -> Int {
        ((self % modulus) + modulus) % modulus
    }
}
