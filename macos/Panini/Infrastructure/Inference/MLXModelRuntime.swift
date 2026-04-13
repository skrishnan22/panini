import Foundation
import MLXLLM
import MLXLMCommon

protocol LocalTextGenerating {
    func generate(
        model: LocalModel,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int,
        temperature: Float
    ) async throws -> String
}

protocol LocalModelLoading {
    func load(model: LocalModel) async throws
}

actor MLXModelRuntime: LocalTextGenerating, LocalModelLoading {
    private var loadedModelID: String?
    private var container: ModelContainer?
    private var progressByModelID: [String: Progress] = [:]

    func load(model: LocalModel) async throws {
        _ = try await container(for: model)
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

    func progress(modelID: String) -> Progress? {
        progressByModelID[modelID]
    }

    private func container(for model: LocalModel) async throws -> ModelContainer {
        if loadedModelID == model.id, let container {
            return container
        }

        let modelID = model.id
        let loadedContainer = try await loadModelContainer(id: modelID) { [weak self] progress in
            Task { await self?.record(progress: progress, modelID: modelID) }
        }

        loadedModelID = model.id
        container = loadedContainer
        return loadedContainer
    }

    private func record(progress: Progress, modelID: String) {
        progressByModelID[modelID] = progress
    }
}
