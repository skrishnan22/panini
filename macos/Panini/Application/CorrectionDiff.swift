import Foundation

enum CorrectionDiff {
    struct Token: Equatable {
        let text: String
        let start: Int
        let end: Int
    }

    private enum Operation {
        case equal(Int, Int, Int, Int)
        case replace(Int, Int, Int, Int)
        case insert(Int, Int, Int, Int)
        case delete(Int, Int, Int, Int)

        var isEqual: Bool {
            if case .equal = self { return true }
            return false
        }
    }

    static func computeChanges(original: String, corrected: String) -> [Change] {
        guard original != corrected else { return [] }

        let originalTokens = tokenize(original)
        let correctedTokens = tokenize(corrected)

        guard !originalTokens.isEmpty || !correctedTokens.isEmpty else { return [] }

        return opcodes(originalTokens.map(\.text), correctedTokens.map(\.text)).compactMap { operation in
            guard !operation.isEqual else { return nil }

            let ranges = expandContext(
                operation: operation,
                originalTokens: originalTokens,
                correctedTokens: correctedTokens
            )

            let originalSlice = sliceWithOffsets(
                source: original,
                tokens: originalTokens,
                startIndex: ranges.originalStart,
                endIndex: ranges.originalEnd
            )
            let replacement = sliceText(
                source: corrected,
                tokens: correctedTokens,
                startIndex: ranges.correctedStart,
                endIndex: ranges.correctedEnd
            )

            guard originalSlice.text != replacement else { return nil }

            return Change(
                offsetStart: originalSlice.start,
                offsetEnd: originalSlice.end,
                originalText: originalSlice.text,
                replacement: replacement,
                category: .grammar
            )
        }
    }

    private static func tokenize(_ text: String) -> [Token] {
        guard let regex = try? NSRegularExpression(pattern: #"\S+"#) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: text) else { return nil }
            return Token(
                text: String(text[tokenRange]),
                start: match.range.location,
                end: NSMaxRange(match.range)
            )
        }
    }

    private static func opcodes(_ original: [String], _ corrected: [String]) -> [Operation] {
        let originalCount = original.count
        let correctedCount = corrected.count
        var lengths = Array(
            repeating: Array(repeating: 0, count: correctedCount + 1),
            count: originalCount + 1
        )

        if originalCount > 0 && correctedCount > 0 {
            for i in stride(from: originalCount - 1, through: 0, by: -1) {
                for j in stride(from: correctedCount - 1, through: 0, by: -1) {
                    if original[i] == corrected[j] {
                        lengths[i][j] = lengths[i + 1][j + 1] + 1
                    } else {
                        lengths[i][j] = max(lengths[i + 1][j], lengths[i][j + 1])
                    }
                }
            }
        }

        var matches: [(Int, Int)] = []
        var i = 0
        var j = 0
        while i < originalCount && j < correctedCount {
            if original[i] == corrected[j] {
                matches.append((i, j))
                i += 1
                j += 1
            } else if lengths[i + 1][j] >= lengths[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }

        var operations: [Operation] = []
        var previousOriginal = 0
        var previousCorrected = 0

        for match in matches {
            appendChangeOperation(
                originalStart: previousOriginal,
                originalEnd: match.0,
                correctedStart: previousCorrected,
                correctedEnd: match.1,
                to: &operations
            )
            operations.append(.equal(match.0, match.0 + 1, match.1, match.1 + 1))
            previousOriginal = match.0 + 1
            previousCorrected = match.1 + 1
        }

        appendChangeOperation(
            originalStart: previousOriginal,
            originalEnd: originalCount,
            correctedStart: previousCorrected,
            correctedEnd: correctedCount,
            to: &operations
        )

        return mergeAdjacentEquals(operations)
    }

    private static func appendChangeOperation(
        originalStart: Int,
        originalEnd: Int,
        correctedStart: Int,
        correctedEnd: Int,
        to operations: inout [Operation]
    ) {
        if originalStart == originalEnd && correctedStart == correctedEnd {
            return
        }

        if originalStart == originalEnd {
            operations.append(.insert(originalStart, originalEnd, correctedStart, correctedEnd))
        } else if correctedStart == correctedEnd {
            operations.append(.delete(originalStart, originalEnd, correctedStart, correctedEnd))
        } else {
            operations.append(.replace(originalStart, originalEnd, correctedStart, correctedEnd))
        }
    }

    private static func mergeAdjacentEquals(_ operations: [Operation]) -> [Operation] {
        var merged: [Operation] = []

        for operation in operations {
            if case let .equal(i1, i2, j1, j2) = operation,
               case let .equal(previousI1, previousI2, previousJ1, previousJ2) = merged.last,
               previousI2 == i1,
               previousJ2 == j1
            {
                merged[merged.count - 1] = .equal(previousI1, i2, previousJ1, j2)
            } else {
                merged.append(operation)
            }
        }

        return merged
    }

    private static func expandContext(
        operation: Operation,
        originalTokens: [Token],
        correctedTokens: [Token]
    ) -> (originalStart: Int, originalEnd: Int, correctedStart: Int, correctedEnd: Int) {
        let originalLength = originalTokens.count
        let correctedLength = correctedTokens.count

        switch operation {
        case let .insert(i1, i2, j1, j2):
            let left = i1 > 0 ? 1 : 0
            let right = i1 < originalLength ? 1 : 0
            return (
                max(0, i1 - left),
                min(originalLength, i2 + right),
                max(0, j1 - left),
                min(correctedLength, j2 + right)
            )

        case let .delete(i1, i2, j1, j2):
            var left = i1 > 0 ? 1 : 0
            if i1 > 1, i1 < originalLength, originalTokens[i1 - 1].text == originalTokens[i1].text {
                left = 2
            }
            return (max(0, i1 - left), i2, max(0, j1 - left), j2)

        case let .replace(i1, i2, j1, j2),
             let .equal(i1, i2, j1, j2):
            return (i1, i2, j1, j2)
        }
    }

    private static func sliceWithOffsets(
        source: String,
        tokens: [Token],
        startIndex: Int,
        endIndex: Int
    ) -> (text: String, start: Int, end: Int) {
        guard !tokens.isEmpty else { return ("", 0, 0) }

        if startIndex >= tokens.count {
            let offset = (source as NSString).length
            return ("", offset, offset)
        }

        if startIndex >= endIndex {
            let offset = tokens[startIndex].start
            return ("", offset, offset)
        }

        let start = tokens[startIndex].start
        let end = tokens[endIndex - 1].end
        return ((source as NSString).substring(with: NSRange(location: start, length: end - start)), start, end)
    }

    private static func sliceText(
        source: String,
        tokens: [Token],
        startIndex: Int,
        endIndex: Int
    ) -> String {
        guard !tokens.isEmpty, startIndex < tokens.count, startIndex < endIndex else { return "" }

        let start = tokens[startIndex].start
        let end = tokens[endIndex - 1].end
        return (source as NSString).substring(with: NSRange(location: start, length: end - start))
    }
}
