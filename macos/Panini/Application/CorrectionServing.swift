import Foundation

protocol CorrectionServing {
    func prepare() async throws
    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult
    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse
}

extension CorrectionServing {
    func prepare() async throws {}

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        .single(try await correct(text: text, mode: mode, preset: preset))
    }
}
