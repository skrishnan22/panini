import XCTest
@testable import GrammarAI

final class KeychainServiceTests: XCTestCase {
    private let testService = "com.panini.test.keychain"

    override func tearDown() {
        super.tearDown()
        KeychainService.delete(service: testService, account: "api-key")
    }

    func testSaveAndRetrieve() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "sk-test-key-123")
        let retrieved = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertEqual(retrieved, "sk-test-key-123")
    }

    func testRetrieveNonexistent() {
        let result = KeychainService.retrieve(service: testService, account: "nonexistent")
        XCTAssertNil(result)
    }

    func testUpdateExistingKey() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "old-key")
        try KeychainService.save(service: testService, account: "api-key", data: "new-key")
        let retrieved = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertEqual(retrieved, "new-key")
    }

    func testDelete() throws {
        try KeychainService.save(service: testService, account: "api-key", data: "to-delete")
        KeychainService.delete(service: testService, account: "api-key")
        let result = KeychainService.retrieve(service: testService, account: "api-key")
        XCTAssertNil(result)
    }
}
