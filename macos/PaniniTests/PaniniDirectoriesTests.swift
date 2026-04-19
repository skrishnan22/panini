import XCTest
@testable import GrammarAI

final class PaniniDirectoriesTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
    }

    func testApplicationSupportDirectoryIsAppOwned() throws {
        let baseDirectory = try makeTemporaryDirectory()

        let directory = try PaniniDirectories.applicationSupportDirectory(baseDirectory: baseDirectory)

        XCTAssertEqual(directory.lastPathComponent, "Panini")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDictionaryAndModelsLiveUnderApplicationSupport() throws {
        let appDirectory = try PaniniDirectories.applicationSupportDirectory(
            baseDirectory: makeTemporaryDirectory()
        )

        let modelsDirectory = try PaniniDirectories.modelsDirectory(applicationSupportDirectory: appDirectory)

        XCTAssertEqual(
            PaniniDirectories.dictionaryFileURL(applicationSupportDirectory: appDirectory).lastPathComponent,
            "dictionary.json"
        )
        XCTAssertEqual(modelsDirectory.deletingLastPathComponent(), appDirectory)
        XCTAssertEqual(modelsDirectory.lastPathComponent, "Models")
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelsDirectory.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }
}
