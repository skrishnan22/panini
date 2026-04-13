import XCTest
@testable import GrammarAI

final class LocalModelStoreTests: XCTestCase {
    func testFetchModelListUsesLocalCatalog() async throws {
        let store = LocalModelStore(statuses: [:])

        let models = try await store.fetchModelList()

        XCTAssertEqual(models.map(\.id), LocalModelCatalog.models.map(\.id))
        XCTAssertEqual(models[0].name, "Qwen 2.5 3B")
        XCTAssertEqual(models[0].ramRequiredGB, 3)
        XCTAssertEqual(models[0].downloadSizeGB, 2.0)
    }

    func testFetchModelStatusUsesInjectedAvailability() async throws {
        let store = LocalModelStore(statuses: [
            LocalModelCatalog.defaultModelID: .ready
        ])

        let status = try await store.fetchModelStatus(modelID: LocalModelCatalog.defaultModelID)

        XCTAssertEqual(status.status, .ready)
    }

    func testUnknownModelStatusThrows() async {
        let store = LocalModelStore(statuses: [:])

        do {
            _ = try await store.fetchModelStatus(modelID: "missing")
            XCTFail("Expected unknown model lookup to throw.")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unknown local model 'missing'.")
        }
    }
}
