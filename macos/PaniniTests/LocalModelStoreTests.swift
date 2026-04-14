import XCTest
@testable import GrammarAI

final class LocalModelStoreTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
    }

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

    func testStartDownloadMarksModelReadyDurably() async throws {
        let modelsDirectory = try makeTemporaryDirectory()
        let loader = StubLocalModelLoader()
        let store = LocalModelStore(loader: loader, modelsDirectory: modelsDirectory)

        try await store.startDownload(modelID: LocalModelCatalog.defaultModelID)

        let status = try await store.fetchModelStatus(modelID: LocalModelCatalog.defaultModelID)
        XCTAssertEqual(status.status, .ready)

        let reloadedStore = LocalModelStore(modelsDirectory: modelsDirectory)
        let reloadedStatus = try await reloadedStore.fetchModelStatus(modelID: LocalModelCatalog.defaultModelID)
        XCTAssertEqual(reloadedStatus.status, .ready)
    }

    func testFetchDownloadProgressUsesLoaderProgress() async throws {
        let loader = StubLocalModelLoader(
            progress: LocalModelDownloadProgress(bytesDownloaded: 25, bytesTotal: 100)
        )
        let store = LocalModelStore(
            statuses: [LocalModelCatalog.defaultModelID: .downloading],
            loader: loader,
            modelsDirectory: try makeTemporaryDirectory()
        )

        let progress = try await store.fetchDownloadProgress(modelID: LocalModelCatalog.defaultModelID)

        XCTAssertEqual(progress.status, "downloading")
        XCTAssertEqual(progress.bytesDownloaded, 25)
        XCTAssertEqual(progress.bytesTotal, 100)
    }

    func testDeleteModelClearsReadyStatus() async throws {
        let modelsDirectory = try makeTemporaryDirectory()
        let store = LocalModelStore(loader: StubLocalModelLoader(), modelsDirectory: modelsDirectory)
        try await store.startDownload(modelID: LocalModelCatalog.defaultModelID)

        try await store.deleteModel(modelID: LocalModelCatalog.defaultModelID)

        let status = try await store.fetchModelStatus(modelID: LocalModelCatalog.defaultModelID)
        XCTAssertEqual(status.status, .notDownloaded)
    }

    func testCancelDownloadReportsUnsupportedOperation() async {
        let store = LocalModelStore(
            statuses: [LocalModelCatalog.defaultModelID: .downloading],
            loader: StubLocalModelLoader()
        )

        do {
            try await store.cancelDownload(modelID: LocalModelCatalog.defaultModelID)
            XCTFail("Expected cancel to throw.")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "Canceling local MLX model downloads is not available yet."
            )
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }
}

private actor StubLocalModelLoader: LocalModelLoading {
    private let progress: LocalModelDownloadProgress?

    init(progress: LocalModelDownloadProgress? = nil) {
        self.progress = progress
    }

    func load(model: LocalModel) async throws {}

    func downloadProgress(modelID: String) async -> LocalModelDownloadProgress? {
        progress
    }
}
