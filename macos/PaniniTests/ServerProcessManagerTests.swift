import XCTest
@testable import GrammarAI

private final class MockProcess: ProcessLaunching {
    var executableURL: URL?
    var arguments: [String]?
    var currentDirectoryURL: URL?
    var environment: [String: String]?
    var isRunning: Bool = false

    var didRun = false
    var didTerminate = false

    func run() throws {
        didRun = true
        isRunning = true
    }

    func terminate() {
        didTerminate = true
        isRunning = false
    }
}

final class ServerProcessManagerTests: XCTestCase {
    func testStartLaunchesConfiguredPythonModule() throws {
        let process = MockProcess()
        let config = AppConfig(serverPort: 9999)
        let manager = ServerProcessManager(config: config) { process }

        try manager.startIfNeeded()

        XCTAssertTrue(process.didRun)
        XCTAssertEqual(process.executableURL?.path, config.pythonExecutablePath)
        XCTAssertEqual(process.arguments ?? [], ["-m", "grammar_ai", "--host", config.serverHost, "--port", "9999"])
    }

    func testStopTerminatesProcess() throws {
        let process = MockProcess()
        let manager = ServerProcessManager(config: AppConfig()) { process }

        try manager.startIfNeeded()
        manager.stop()

        XCTAssertTrue(process.didTerminate)
    }
}
