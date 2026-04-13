import Foundation
import XCTest
@testable import GrammarAI

final class LocalDictionaryStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    func testStartsEmptyWhenFileDoesNotExist() async throws {
        let store = LocalDictionaryStore(fileURL: dictionaryURL)

        let words = try await store.listWords()

        XCTAssertEqual(words, [])
    }

    func testAddsTrimmedWordsAndReturnsSortedUniqueWords() async throws {
        let store = LocalDictionaryStore(fileURL: dictionaryURL)

        try await store.addWord("  MLX  ")
        try await store.addWord("Panini")
        try await store.addWord("MLX")
        try await store.addWord("")

        let words = try await store.listWords()

        XCTAssertEqual(words, ["MLX", "Panini"])
    }

    func testPersistsWordsToJSONFile() async throws {
        let store = LocalDictionaryStore(fileURL: dictionaryURL)
        try await store.addWord("Qwen")

        let reloaded = LocalDictionaryStore(fileURL: dictionaryURL)
        let words = try await reloaded.listWords()

        XCTAssertEqual(words, ["Qwen"])
    }

    func testRemovesWords() async throws {
        let store = LocalDictionaryStore(fileURL: dictionaryURL)
        try await store.addWord("MLX")
        try await store.addWord("Qwen")

        try await store.removeWord("MLX")
        let words = try await store.listWords()

        XCTAssertEqual(words, ["Qwen"])
    }

    private var dictionaryURL: URL {
        temporaryDirectory.appendingPathComponent("dictionary.json")
    }
}
