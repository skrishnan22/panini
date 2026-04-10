import Foundation

public struct AppConfig: Sendable {
    public let serverHost: String
    public let serverPort: Int
    public let pythonExecutablePath: String
    public let serverModule: String
    public let requestTimeout: TimeInterval
    public let serverHealthTimeout: TimeInterval
    public let undoWindowSeconds: TimeInterval
    public let defaultPreset: String
    public let defaultMode: CorrectionMode
    public let defaultModelID: String
    public let serverEntryWorkingDirectory: URL

    private static let envServerDir = "PANINI_SERVER_DIR"
    private static let envPythonPath = "PANINI_PYTHON_PATH"
    private static let envServerHost = "PANINI_SERVER_HOST"
    private static let envServerPort = "PANINI_SERVER_PORT"
    private static let envModelID = "PANINI_MODEL_ID"

    public init(
        serverHost: String = "127.0.0.1",
        serverPort: Int = 8765,
        pythonExecutablePath: String? = nil,
        serverModule: String = "panini",
        requestTimeout: TimeInterval = 20,
        serverHealthTimeout: TimeInterval = 2,
        undoWindowSeconds: TimeInterval = 10,
        defaultPreset: String = "fix",
        defaultMode: CorrectionMode = .review,
        defaultModelID: String = "qwen-2.5-3b",
        serverEntryWorkingDirectory: URL? = nil
    ) {
        let environment = ProcessInfo.processInfo.environment
        let resolvedServerDir = serverEntryWorkingDirectory ?? Self.resolveServerDirectory(environment: environment)
        let resolvedHost = environment[Self.envServerHost] ?? serverHost
        let resolvedPort = Int(environment[Self.envServerPort] ?? "") ?? serverPort
        let resolvedPythonPath = pythonExecutablePath
            ?? environment[Self.envPythonPath]
            ?? Self.resolvePythonPath(serverDir: resolvedServerDir)

        let resolvedModelID = environment[Self.envModelID] ?? defaultModelID

        self.serverHost = resolvedHost
        self.serverPort = resolvedPort
        self.pythonExecutablePath = resolvedPythonPath
        self.serverModule = serverModule
        self.requestTimeout = requestTimeout
        self.serverHealthTimeout = serverHealthTimeout
        self.undoWindowSeconds = undoWindowSeconds
        self.defaultPreset = defaultPreset
        self.defaultMode = defaultMode
        self.defaultModelID = resolvedModelID
        self.serverEntryWorkingDirectory = resolvedServerDir
    }

    public var serverBaseURL: URL {
        URL(string: "http://\(serverHost):\(serverPort)")!
    }

    private static func resolveServerDirectory(environment: [String: String]) -> URL {
        let fileManager = FileManager.default
        if let envDir = environment[Self.envServerDir]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envDir.isEmpty
        {
            let expanded = (envDir as NSString).expandingTildeInPath
            let envURL = URL(fileURLWithPath: expanded)
            if fileManager.fileExists(atPath: envURL.path) {
                return envURL
            }
        }

        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let executableDir = URL(fileURLWithPath: ProcessInfo.processInfo.arguments.first ?? current.path)
            .deletingLastPathComponent()
        let bundleDir = Bundle.main.bundleURL.deletingLastPathComponent()

        let roots = [current, executableDir, bundleDir]
        let candidates = roots.flatMap { root in
            ancestorCandidates(for: root)
        }

        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let fallbackCandidates: [URL] = [
            current.appendingPathComponent("panini/server", isDirectory: true),
            current.appendingPathComponent("server", isDirectory: true)
        ]

        for candidate in fallbackCandidates {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return fallbackCandidates[0]
    }

    private static func ancestorCandidates(for root: URL) -> [URL] {
        var results: [URL] = []
        var current = root
        var hops = 0

        while hops < 10 {
            results.append(current.appendingPathComponent("panini/server", isDirectory: true))
            results.append(current.appendingPathComponent("server", isDirectory: true))

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
            hops += 1
        }

        return results
    }

    private static func resolvePythonPath(serverDir: URL) -> String {
        let fileManager = FileManager.default
        let venvPython3 = serverDir.appendingPathComponent(".venv/bin/python3").path
        if fileManager.fileExists(atPath: venvPython3) {
            return venvPython3
        }

        let venvPython = serverDir.appendingPathComponent(".venv/bin/python").path
        if fileManager.fileExists(atPath: venvPython) {
            return venvPython
        }

        return "/usr/bin/python3"
    }
}
