import Foundation

struct DictionaryService {
    private struct WordRequest: Encodable {
        let word: String
    }

    private struct DictionaryResponse: Decodable {
        let words: [String]
    }

    let baseURL: URL
    let timeout: TimeInterval
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval = 10, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func listWords() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("dictionary"))
        request.timeoutInterval = timeout
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(DictionaryResponse.self, from: data).words
    }

    func addWord(_ word: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("dictionary"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(WordRequest(word: word))
        _ = try await session.data(for: request)
    }

    func removeWord(_ word: String) async throws {
        let encodedWord = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        var request = URLRequest(url: baseURL.appendingPathComponent("dictionary/\(encodedWord)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        _ = try await session.data(for: request)
    }
}
