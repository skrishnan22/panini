import XCTest
@testable import GrammarAI

final class ModelManagementServiceTests: XCTestCase {
    private var session: URLSession!
    private var service: ModelManagementService!

    override func setUp() {
        super.setUp()
        session = makeMockSession()
        service = ModelManagementService(baseURL: URL(string: "http://test")!, session: session)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchModelStatus() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/models/gemma-4-e4b/status"))
            let body = #"{"model_id":"gemma-4-e4b","status":"ready"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        let status = try await service.fetchModelStatus(modelID: "gemma-4-e4b")
        XCTAssertEqual(status.modelID, "gemma-4-e4b")
        XCTAssertEqual(status.status, .ready)
    }

    func testStartDownload() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = #"{"status":"started","model_id":"gemma-4-e4b"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        try await service.startDownload(modelID: "gemma-4-e4b")
    }

    func testFetchDownloadProgress() async throws {
        MockURLProtocol.handler = { request in
            let body = #"{"model_id":"gemma-4-e4b","status":"downloading","bytes_downloaded":500,"bytes_total":1000,"error":null}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        let progress = try await service.fetchDownloadProgress(modelID: "gemma-4-e4b")
        XCTAssertEqual(progress.bytesDownloaded, 500)
        XCTAssertEqual(progress.bytesTotal, 1000)
    }

    func testDeleteModel() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            let body = #"{"status":"deleted","model_id":"gemma-4-e4b"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        try await service.deleteModel(modelID: "gemma-4-e4b")
    }

    func testFetchModelList() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertTrue(request.url!.path.hasSuffix("/models"))
            let body = """
            {"models":[{"id":"gemma-4-e4b","name":"Gemma 4 E4B","params":"4B","ram_required_gb":4,"download_size_gb":2.5,"default_for":"grammar"}]}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        let models = try await service.fetchModelList()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].id, "gemma-4-e4b")
        XCTAssertEqual(models[0].ramRequiredGB, 4)
        XCTAssertEqual(models[0].downloadSizeGB, 2.5)
        XCTAssertEqual(models[0].defaultFor, "grammar")
    }

    func testCancelDownload() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.path.hasSuffix("/download/cancel"))
            let body = #"{"status":"cancelled","model_id":"gemma-4-e4b"}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        try await service.cancelDownload(modelID: "gemma-4-e4b")
    }

    func testFetchModelStatusThrowsOnFailure() async {
        MockURLProtocol.handler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await service.fetchModelStatus(modelID: "gemma-4-e4b")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is PaniniError)
        }
    }
}
