import Foundation

struct VariantResponseParser {
    private let optionPattern = #"\[\[?option:(.*?)\]\]?\s*([\s\S]*?)\s*\[\[?/option\]\]?"#

    func parse(_ raw: String, expectedCount: Int) -> [RewriteVariant] {
        var options = taggedOptions(in: raw)
        options = dedupePreservingOrder(options)

        if options.isEmpty {
            let fallback = normalize(raw)
            if !fallback.isEmpty {
                options = [("recommended", fallback)]
            }
        }

        var variants: [RewriteVariant] = []
        var alternativeIndex = 0

        for (index, option) in options.prefix(expectedCount).enumerated() {
            let isRecommended = option.tag == "recommended"
            let label: String
            if isRecommended {
                label = "Recommended"
            } else {
                alternativeIndex += 1
                label = alternativeIndex == 1 ? "Alternative" : "Alternative \(alternativeIndex)"
            }

            variants.append(RewriteVariant(
                id: "variant-\(index + 1)",
                label: label,
                text: option.text,
                isRecommended: isRecommended
            ))
        }

        return variants
    }

    private func taggedOptions(in raw: String) -> [(tag: String, text: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: optionPattern,
            options: [.caseInsensitive]
        ) else { return [] }

        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        return regex.matches(in: raw, range: range).compactMap { match in
            guard
                let tagRange = Range(match.range(at: 1), in: raw),
                let textRange = Range(match.range(at: 2), in: raw)
            else { return nil }

            return (
                tag: raw[tagRange].trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                text: normalize(String(raw[textRange]))
            )
        }
    }

    private func dedupePreservingOrder(_ options: [(tag: String, text: String)]) -> [(tag: String, text: String)] {
        var deduped: [(tag: String, text: String)] = []
        var seen = Set<String>()

        for option in options {
            guard !option.text.isEmpty, !seen.contains(option.text) else { continue }
            seen.insert(option.text)
            deduped.append(option)
        }

        return deduped
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
