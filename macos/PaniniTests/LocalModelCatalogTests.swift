import XCTest
@testable import GrammarAI

final class LocalModelCatalogTests: XCTestCase {
    func testDefaultModelIsQwen25ThreeB() {
        XCTAssertEqual(LocalModelCatalog.defaultModel.id, "mlx-community/Qwen2.5-3B-Instruct-4bit")
        XCTAssertEqual(LocalModelCatalog.defaultModel.displayName, "Qwen 2.5 3B")
        XCTAssertEqual(LocalModelCatalog.defaultModel.params, "3B")
        XCTAssertEqual(LocalModelCatalog.defaultModel.estimatedRAMGB, 3)
        XCTAssertEqual(LocalModelCatalog.defaultModel.estimatedDownloadGB, 2.0)
        XCTAssertFalse(LocalModelCatalog.defaultModel.supportsNoThink)
    }

    func testCatalogIncludesOptionalQwen3FourBModel() {
        let model = LocalModelCatalog.model(id: "mlx-community/Qwen3-4B-4bit")

        XCTAssertEqual(model?.displayName, "Qwen3 4B")
        XCTAssertFalse(model?.isDefault ?? true)
        XCTAssertTrue(model?.supportsNoThink ?? false)
    }

    func testCatalogIncludesOptionalQwenSmallModelWithWarning() {
        let model = LocalModelCatalog.model(id: "mlx-community/Qwen3-1.7B-4bit")

        XCTAssertEqual(model?.displayName, "Qwen3 1.7B")
        XCTAssertNotNil(model?.qualityWarning)
        XCTAssertFalse(model?.isDefault ?? true)
    }

    func testMigratesOldDefaultModelIDs() {
        XCTAssertEqual(
            LocalModelCatalog.migratedModelID(from: "gemma-4-e4b"),
            LocalModelCatalog.defaultModelID
        )
        XCTAssertEqual(
            LocalModelCatalog.migratedModelID(from: "qwen-2.5-3b"),
            LocalModelCatalog.defaultModelID
        )
        XCTAssertEqual(LocalModelCatalog.migratedModelID(from: ""), LocalModelCatalog.defaultModelID)
    }

    func testPreservesKnownNewModelID() {
        XCTAssertEqual(
            LocalModelCatalog.migratedModelID(from: "mlx-community/Qwen3-1.7B-4bit"),
            "mlx-community/Qwen3-1.7B-4bit"
        )
    }
}
