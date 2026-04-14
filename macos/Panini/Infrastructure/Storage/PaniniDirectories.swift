import Foundation

enum PaniniDirectories {
    static let applicationDirectoryName = "Panini"
    static let dictionaryFileName = "dictionary.json"
    static let modelsDirectoryName = "Models"

    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return try applicationSupportDirectory(baseDirectory: baseDirectory, fileManager: fileManager)
    }

    static func applicationSupportDirectory(
        baseDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = baseDirectory.appendingPathComponent(applicationDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func dictionaryFileURL(fileManager: FileManager = .default) throws -> URL {
        dictionaryFileURL(applicationSupportDirectory: try applicationSupportDirectory(fileManager: fileManager))
    }

    static func dictionaryFileURL(applicationSupportDirectory: URL) -> URL {
        applicationSupportDirectory.appendingPathComponent(dictionaryFileName)
    }

    static func modelsDirectory(fileManager: FileManager = .default) throws -> URL {
        try modelsDirectory(
            applicationSupportDirectory: applicationSupportDirectory(fileManager: fileManager),
            fileManager: fileManager
        )
    }

    static func modelsDirectory(
        applicationSupportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = applicationSupportDirectory.appendingPathComponent(modelsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fallbackApplicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseDirectory.appendingPathComponent(applicationDirectoryName, isDirectory: true)
    }
}
