import Foundation

protocol ProcessLaunching: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var currentDirectoryURL: URL? { get set }
    var environment: [String: String]? { get set }
    var isRunning: Bool { get }

    func run() throws
    func terminate()
}

extension Process: ProcessLaunching {}

protocol ServerControlling: AnyObject {
    func startIfNeeded() throws
    func stop()
    func restart(backend: String, modelID: String, cloudURL: String?, cloudKey: String?) throws
}

final class ServerProcessManager: ServerControlling {
    private let config: AppConfig
    private let makeProcess: () -> ProcessLaunching
    private var process: ProcessLaunching?

    init(
        config: AppConfig,
        makeProcess: @escaping () -> ProcessLaunching = { Process() }
    ) {
        self.config = config
        self.makeProcess = makeProcess
    }

    func startIfNeeded() throws {
        if let process, process.isRunning {
            AppLogger.server.debug("Server already running; skipping start.")
            return
        }

        guard FileManager.default.fileExists(atPath: config.serverEntryWorkingDirectory.path) else {
            throw PaniniError.backendRequestFailed(
                "Server directory not found at '\(config.serverEntryWorkingDirectory.path)'. Set PANINI_SERVER_DIR in the Xcode scheme environment."
            )
        }

        let process = makeProcess()
        process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)
        process.arguments = [
            "-m", config.serverModule,
            "--host", config.serverHost,
            "--port", "\(config.serverPort)",
            "--model", config.defaultModelID
        ]
        process.currentDirectoryURL = config.serverEntryWorkingDirectory

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        AppLogger.server.info(
            "Starting server process: python=\(self.config.pythonExecutablePath, privacy: .public) cwd=\(self.config.serverEntryWorkingDirectory.path, privacy: .public) host=\(self.config.serverHost, privacy: .public) port=\(self.config.serverPort) model=\(self.config.defaultModelID, privacy: .public)"
        )

        try process.run()
        self.process = process
        AppLogger.server.info("Server process started.")
    }

    func stop() {
        guard let process else { return }
        if process.isRunning {
            AppLogger.server.info("Stopping server process.")
            process.terminate()
        }
        self.process = nil
    }

    func restart(backend: String, modelID: String, cloudURL: String?, cloudKey: String?) throws {
        stop()

        guard FileManager.default.fileExists(atPath: config.serverEntryWorkingDirectory.path) else {
            throw PaniniError.backendRequestFailed(
                "Server directory not found at '\(config.serverEntryWorkingDirectory.path)'. Set PANINI_SERVER_DIR in the Xcode scheme environment."
            )
        }

        let process = makeProcess()
        process.executableURL = URL(fileURLWithPath: config.pythonExecutablePath)

        var args = [
            "-m", config.serverModule,
            "--host", config.serverHost,
            "--port", "\(config.serverPort)",
            "--backend", backend,
            "--model", modelID,
        ]

        if backend == "cloud", let cloudURL, let cloudKey {
            args.append(contentsOf: ["--cloud-url", cloudURL, "--cloud-key", cloudKey])
        }

        process.arguments = args
        process.currentDirectoryURL = config.serverEntryWorkingDirectory

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        AppLogger.server.info(
            "Restarting server: backend=\(backend, privacy: .public) model=\(modelID, privacy: .public)"
        )

        try process.run()
        self.process = process
    }
}
