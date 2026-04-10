import Foundation

protocol CorrectionServing {
    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult
    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse
}

extension CorrectionServing {
    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        .single(try await correct(text: text, mode: mode, preset: preset))
    }
}

struct CorrectionAPIClient: CorrectionServing {
    private struct CorrectRequest: Encodable {
        let text: String
        let mode: CorrectionMode
        let preset: String
        let avoidOutputs: [String]

        enum CodingKeys: String, CodingKey {
            case text
            case mode
            case preset
            case avoidOutputs = "avoid_outputs"
        }
    }

    private struct ResponseEnvelope: Decodable {
        let kind: Kind

        enum Kind: String, Decodable {
            case single
            case variants
        }
    }

    let baseURL: URL
    let timeout: TimeInterval
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval = 20, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        let response = try await correct(text: text, mode: mode, preset: preset, avoidOutputs: [])
        guard case let .single(payload) = response else {
            throw PaniniError.backendRequestFailed("Expected a single correction payload.")
        }
        return payload
    }

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("correct"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            CorrectRequest(text: text, mode: mode, preset: preset, avoidOutputs: avoidOutputs)
        )

        AppLogger.api.info(
            "POST /correct mode=\(mode.rawValue, privacy: .public) preset=\(preset, privacy: .public) text_chars=\(text.count) avoid_outputs=\(avoidOutputs.count)"
        )

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLogger.api.info("POST /correct response status=\(statusCode) bytes=\(data.count)")
        guard (200 ..< 300).contains(statusCode) else {
            throw PaniniError.backendRequestFailed("Backend returned status \(statusCode).")
        }

        do {
            let decoder = JSONDecoder()
            let envelope = try decoder.decode(ResponseEnvelope.self, from: data)

            switch envelope.kind {
            case .single:
                return .single(try decoder.decode(SingleCorrectionPayload.self, from: data))
            case .variants:
                return .variants(try decoder.decode(VariantCorrectionPayload.self, from: data))
            }
        } catch {
            throw PaniniError.backendRequestFailed("Failed to decode backend response: \(error)")
        }
    }
}
