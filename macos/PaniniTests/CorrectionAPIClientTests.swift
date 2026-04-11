import XCTest
@testable import GrammarAI

final class CorrectionAPIClientTests: XCTestCase {
    private func requestPayload(from request: URLRequest) throws -> [String: Any] {
        let bodyData = try requestBodyData(from: request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
    }

    private func requestBodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                throw try XCTUnwrap(stream.streamError)
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCorrectDecodesSingleResponse() async throws {
        let json = """
        {"kind":"single","original":"i has a error","corrected":"I have an error","changes":[],"model_used":"gemma-4-e4b","backend_used":"mlx"}
        """.data(using: .utf8)!

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/correct")
            XCTAssertEqual(request.httpMethod, "POST")
            let payload = try self.requestPayload(from: request)
            XCTAssertEqual(payload["avoid_outputs"] as? [String], [])
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let client = CorrectionAPIClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: makeMockSession()
        )

        let result = try await client.correct(
            text: "i has a error",
            mode: .review,
            preset: "fix",
            avoidOutputs: []
        )

        guard case let .single(payload) = result else {
            return XCTFail("Expected single payload")
        }

        XCTAssertEqual(payload.corrected, "I have an error")
        XCTAssertEqual(payload.modelUsed, "gemma-4-e4b")
        XCTAssertEqual(payload.backendUsed, "mlx")
    }

    func testCorrectDecodesVariantResponse() async throws {
        let json = """
        {
          "kind":"variants",
          "original":"hey checking in",
          "variants":[
            {"id":"variant-1","label":"Recommended","text":"Hello, I am following up.","is_recommended":true},
            {"id":"variant-2","label":"Alternative","text":"Just checking in on this.","is_recommended":false}
          ],
          "model_used":"gemma-4-e4b",
          "backend_used":"mlx"
        }
        """.data(using: .utf8)!

        MockURLProtocol.handler = { request in
            let payload = try self.requestPayload(from: request)
            XCTAssertEqual(payload["avoid_outputs"] as? [String], ["Hello, I am following up."])
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                json
            )
        }

        let client = CorrectionAPIClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: makeMockSession()
        )

        let result = try await client.correct(
            text: "hey checking in",
            mode: .review,
            preset: "professional",
            avoidOutputs: ["Hello, I am following up."]
        )

        guard case let .variants(payload) = result else {
            return XCTFail("Expected variants payload")
        }

        XCTAssertEqual(payload.variants.count, 2)
        XCTAssertEqual(payload.variants.first?.isRecommended, true)
    }

    func testCorrectThrowsForNonSuccessStatus() async {
        MockURLProtocol.handler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = CorrectionAPIClient(
            baseURL: URL(string: "http://127.0.0.1:8765")!,
            session: makeMockSession()
        )

        do {
            _ = try await client.correct(text: "x", mode: .review, preset: "fix", avoidOutputs: [])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is PaniniError)
        }
    }
}
