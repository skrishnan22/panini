import XCTest
@testable import GrammarAI

final class ServerHealthClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testHealthReturnsTrueFor200() async {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/health")
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = ServerHealthClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: makeMockSession()
        )

        let isHealthy = await client.isHealthy()
        XCTAssertTrue(isHealthy)
    }

    func testHealthReturnsFalseForNon200() async {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = ServerHealthClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: makeMockSession()
        )

        let isHealthy = await client.isHealthy()
        XCTAssertFalse(isHealthy)
    }
}
