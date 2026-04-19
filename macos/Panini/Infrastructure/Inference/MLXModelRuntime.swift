import Foundation
import Hub
import MLXLLM
import MLXLMCommon

protocol LocalTextGenerating: Sendable {
    func generate(
        model: LocalModel,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> String
}

protocol LocalModelLoading: Sendable {
    func download(model: LocalModel) async throws
    func load(model: LocalModel) async throws
    func downloadProgress(modelID: String) async -> LocalModelDownloadProgress?
}

struct LocalModelDownloadProgress: Sendable {
    let bytesDownloaded: Int?
    let bytesTotal: Int?
}

actor MLXModelRuntime: LocalTextGenerating, LocalModelLoading {
    private var loadedModelID: String?
    private var container: ModelContainer?
    private var progressByModelID: [String: Progress] = [:]
    private let hub: HubApi

    init(modelsDirectory: URL? = nil) {
        let directory = modelsDirectory
            ?? (try? PaniniDirectories.modelsDirectory())
            ?? PaniniDirectories.fallbackApplicationSupportDirectory()
                .appendingPathComponent(PaniniDirectories.modelsDirectoryName, isDirectory: true)

        self.hub = HubApi(downloadBase: directory, cache: nil)
    }

    func load(model: LocalModel) async throws {
        _ = try await container(for: model)
    }

    func download(model: LocalModel) async throws {
        let modelID = model.id
        _ = try await downloadModel(
            hub: hub,
            configuration: ModelConfiguration(id: modelID)
        ) { [weak self] progress in
            Task { await self?.record(progress: progress, modelID: modelID) }
        }
    }

    func generate(
        model: LocalModel,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> String {
        let container = try await container(for: model)
        let parameters = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let session = ChatSession(
            container,
            instructions: systemPrompt,
            generateParameters: parameters
        )

        return try await session.respond(to: userMessage)
    }

    func downloadProgress(modelID: String) async -> LocalModelDownloadProgress? {
        guard let progress = progressByModelID[modelID] else { return nil }

        return LocalModelDownloadProgress(
            bytesDownloaded: Self.intValue(progress.completedUnitCount),
            bytesTotal: progress.totalUnitCount > 0 ? Self.intValue(progress.totalUnitCount) : nil
        )
    }

    private func container(for model: LocalModel) async throws -> ModelContainer {
        if loadedModelID == model.id, let container {
            return container
        }

        let modelID = model.id
        let loadedContainer = try await loadModelContainer(hub: hub, id: modelID) { [weak self] progress in
            Task { await self?.record(progress: progress, modelID: modelID) }
        }

        loadedModelID = model.id
        container = loadedContainer
        return loadedContainer
    }

    private func record(progress: Progress, modelID: String) {
        progressByModelID[modelID] = progress
    }

    private static func intValue(_ value: Int64) -> Int? {
        guard value >= 0, value <= Int64(Int.max) else { return nil }
        return Int(value)
    }
}
