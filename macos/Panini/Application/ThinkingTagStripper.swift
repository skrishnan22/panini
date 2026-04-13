import Foundation

enum ThinkingTagStripper {
    static func strip(_ output: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<think>[\s\S]*?</think>"#,
            options: [.caseInsensitive]
        ) else {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        let stripped = regex.stringByReplacingMatches(
            in: output,
            range: range,
            withTemplate: ""
        )

        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
