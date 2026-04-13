import Foundation

actor LocalModelStore: ModelManaging {
    private var statuses: [String: ModelDownloadStatus]
    private let loader: LocalModelLoading?

    init(statuses: [String: ModelDownloadStatus] = [:], loader: LocalModelLoading? = nil) {
        self.statuses = statuses
        self.loader = loader
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

        return ModelStatusResponse(
            modelID: modelID,
            status: statuses[modelID] ?? .notDownloaded
        )
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
            try await loader.load(model: model)
            statuses[modelID] = .ready
        } catch {
            statuses[modelID] = .notDownloaded
            throw error
        }
    }

    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        let status = try await fetchModelStatus(modelID: modelID)
        return DownloadProgressResponse(
            modelID: modelID,
            status: status.status.rawValue,
            bytesDownloaded: nil,
            bytesTotal: nil,
            error: nil
        )
    }

    func cancelDownload(modelID: String) async throws {
        guard LocalModelCatalog.model(id: modelID) != nil else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }
    }

    func deleteModel(modelID: String) async throws {
        guard LocalModelCatalog.model(id: modelID) != nil else {
            throw PaniniError.backendRequestFailed("Unknown local model '\(modelID)'.")
        }

        throw PaniniError.backendRequestFailed("Deleting local model cache is not available yet.")
    }
}
