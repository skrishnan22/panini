import Foundation
import Hub

actor LocalModelStore: ModelManaging, LocalModelReadinessChecking {
    private struct ReadyMarker: Codable {
        let modelID: String
        let createdAt: Date
    }

    private static let readyMarkerFileName = ".panini-ready"

    private var statuses: [String: ModelDownloadStatus]
    private let loader: LocalModelLoading?
    private let hub: HubApi
    private let fileManager: FileManager

    init(
        statuses: [String: ModelDownloadStatus] = [:],
        loader: LocalModelLoading? = nil,
        modelsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.statuses = statuses
        self.loader = loader
        self.fileManager = fileManager

        let directory = modelsDirectory
            ?? (try? PaniniDirectories.modelsDirectory(fileManager: fileManager))
            ?? PaniniDirectories.fallbackApplicationSupportDirectory(fileManager: fileManager)
                .appendingPathComponent(PaniniDirectories.modelsDirectoryName, isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.hub = HubApi(downloadBase: directory, cache: nil)
    }

    func fetchModelList() async throws -> [ModelListEntry] {
        LocalModelCatalog.models.map { model in
            ModelListEntry(
                id: model.id,
                name: model.displayName,
                params: model.params,
                ramRequiredGB: model.estimatedRAMGB,
                downloadSizeGB: model.estimatedDownloadGB,
                defaultFor: model.isDefault ? "mlx" : nil
            )
        }
    }

    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse {
        guard LocalModelCatalog.model(id: modelID) != nil else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }

        return ModelStatusResponse(modelID: modelID, status: status(for: modelID))
    }

    func startDownload(modelID: String) async throws {
        guard let model = LocalModelCatalog.model(id: modelID) else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }
        guard let loader else {
            throw PaniniError.backendRequestFailed("Local model downloads will be enabled when MLX runtime is wired.")
        }

        statuses[modelID] = .downloading
        do {
            try await loader.download(model: model)
            try markReady(modelID: modelID)
            statuses[modelID] = .ready
        } catch {
            statuses[modelID] = .notDownloaded
            throw error
        }
    }

    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        let status = try await fetchModelStatus(modelID: modelID)
        let progress = status.status == .downloading
            ? await loader?.downloadProgress(modelID: modelID)
            : nil

        return DownloadProgressResponse(
            modelID: modelID,
            status: status.status.rawValue,
            bytesDownloaded: progress?.bytesDownloaded,
            bytesTotal: progress?.bytesTotal,
            error: nil
        )
    }

    func cancelDownload(modelID: String) async throws {
        guard LocalModelCatalog.model(id: modelID) != nil else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }

        throw PaniniError.backendRequestFailed("Canceling local MLX model downloads is not available yet.")
    }

    func deleteModel(modelID: String) async throws {
        guard LocalModelCatalog.model(id: modelID) != nil else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }

        let directory = modelDirectory(modelID: modelID)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        statuses[modelID] = .notDownloaded
    }

    func isModelReady(_ modelID: String) async -> Bool {
        guard LocalModelCatalog.model(id: modelID) != nil else { return false }
        return status(for: modelID) == .ready
    }

    private func status(for modelID: String) -> ModelDownloadStatus {
        if let status = statuses[modelID], status != .notDownloaded {
            return status
        }

        return fileManager.fileExists(atPath: readyMarkerURL(modelID: modelID).path)
            ? .ready
            : .notDownloaded
    }

    private func markReady(modelID: String) throws {
        let directory = modelDirectory(modelID: modelID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let marker = ReadyMarker(modelID: modelID, createdAt: Date())
        let data = try JSONEncoder().encode(marker)
        try data.write(to: readyMarkerURL(modelID: modelID), options: [.atomic])
    }

    private func readyMarkerURL(modelID: String) -> URL {
        modelDirectory(modelID: modelID)
            .appendingPathComponent(Self.readyMarkerFileName)
    }

    private func modelDirectory(modelID: String) -> URL {
        hub.localRepoLocation(Hub.Repo(id: modelID))
    }
}
