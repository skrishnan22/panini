import Foundation

struct RoutingCorrectionService: CorrectionServing {
    private let userSettings: UserSettings
    private let localProvider: CorrectionServing
    private let cloudProvider: CorrectionServing

    init(
        userSettings: UserSettings,
        localProvider: CorrectionServing,
        cloudProvider: CorrectionServing = CloudUnavailableCorrectionProvider()
    ) {
        self.userSettings = userSettings
        self.localProvider = localProvider
        self.cloudProvider = cloudProvider
    }

    func prepare() async throws {
        switch userSettings.backendChoice {
        case .local:
            try await localProvider.prepare()
        case .cloud:
            try await cloudProvider.prepare()
        }
    }

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        let response = try await correct(text: text, mode: mode, preset: preset, avoidOutputs: [])
        guard case let .single(result) = response else {
            throw PaniniError.backendRequestFailed("Expected a single correction payload.")
        }
        return result
    }

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        switch userSettings.backendChoice {
        case .local:
            return try await localProvider.correct(
                text: text,
                mode: mode,
                preset: preset,
                avoidOutputs: avoidOutputs
            )
        case .cloud:
            return try await cloudProvider.correct(
                text: text,
                mode: mode,
                preset: preset,
                avoidOutputs: avoidOutputs
            )
        }
    }
}

private struct CloudUnavailableCorrectionProvider: CorrectionServing {
    private let message = "Cloud provider is not configured yet."

    func prepare() async throws {
        throw PaniniError.backendRequestFailed(message)
    }

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        throw PaniniError.backendRequestFailed(message)
    }
}
