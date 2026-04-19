import Foundation

actor LocalDictionaryStore: DictionaryManaging {
    private struct Payload: Codable {
        var words: [String]
    }

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL = LocalDictionaryStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func listWords() async throws -> [String] {
        try loadWords().sorted()
    }

    func addWord(_ word: String) async throws {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var words = try loadWords()
        words.insert(trimmed)
        try save(words)
    }

    func removeWord(_ word: String) async throws {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var words = try loadWords()
        words.remove(trimmed)
        try save(words)
    }

    private func loadWords() throws -> Set<String> {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        let data = try Data(contentsOf: fileURL)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return Set(payload.words)
    }

    private func save(_ words: Set<String>) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let payload = Payload(words: words.sorted())
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        (try? PaniniDirectories.dictionaryFileURL())
            ?? PaniniDirectories.fallbackApplicationSupportDirectory()
                .appendingPathComponent(PaniniDirectories.dictionaryFileName)
    }
}
