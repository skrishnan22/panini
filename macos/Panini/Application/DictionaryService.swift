import Foundation

protocol DictionaryManaging: Sendable {
    func listWords() async throws -> [String]
    func addWord(_ word: String) async throws
    func removeWord(_ word: String) async throws
}
