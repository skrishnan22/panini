import XCTest
@testable import GrammarAI

final class RoutingCorrectionServiceTests: XCTestCase {
    func testCloudBackendFailsExplicitlyWhenNoCloudProviderIsConfigured() async throws {
        let suiteName = "RoutingCorrectionServiceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = UserSettings(defaults: defaults)
        settings.backendChoice = .cloud

        let localProvider = SucceedingCorrectionProvider()
        let service = RoutingCorrectionService(
            userSettings: settings,
            localProvider: localProvider
        )

        do {
            _ = try await service.correct(text: "hello", mode: .review, preset: "fix")
            XCTFail("Expected cloud mode to fail without a direct cloud provider.")
        } catch {
            let requestCount = await localProvider.requestCount
            XCTAssertEqual(error.localizedDescription, "Cloud provider is not configured yet.")
            XCTAssertEqual(requestCount, 0)
        }
    }
}

private actor SucceedingCorrectionProvider: CorrectionServing {
    private var requests = 0

    var requestCount: Int { requests }

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        requests += 1
        return CorrectionResult(
            original: text,
            corrected: text,
            changes: [],
            modelUsed: "test",
            backendUsed: "test"
        )
    }
}
