import Foundation

struct LocalModel: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let params: String
    let estimatedRAMGB: Int
    let estimatedDownloadGB: Double
    let isDefault: Bool
    let supportsNoThink: Bool
    let qualityWarning: String?

    init(
        id: String,
        displayName: String,
        params: String,
        estimatedRAMGB: Int,
        estimatedDownloadGB: Double,
        isDefault: Bool,
        supportsNoThink: Bool,
        qualityWarning: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.params = params
        self.estimatedRAMGB = estimatedRAMGB
        self.estimatedDownloadGB = estimatedDownloadGB
        self.isDefault = isDefault
        self.supportsNoThink = supportsNoThink
        self.qualityWarning = qualityWarning
    }
}

enum LocalModelCatalog {
    static let defaultModelID = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    static let models: [LocalModel] = [
        LocalModel(
            id: defaultModelID,
            displayName: "Qwen 2.5 3B",
            params: "3B",
            estimatedRAMGB: 3,
            estimatedDownloadGB: 2.0,
            isDefault: true,
            supportsNoThink: false
        ),
        LocalModel(
            id: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen3 4B",
            params: "4B",
            estimatedRAMGB: 8,
            estimatedDownloadGB: 2.4,
            isDefault: false,
            supportsNoThink: true
        ),
        LocalModel(
            id: "mlx-community/Qwen3-1.7B-4bit",
            displayName: "Qwen3 1.7B",
            params: "1.7B",
            estimatedRAMGB: 4,
            estimatedDownloadGB: 1.0,
            isDefault: false,
            supportsNoThink: true,
            qualityWarning: "Fast, but less reliable for grammar fixes."
        ),
    ]

    static var defaultModel: LocalModel {
        models.first { $0.isDefault } ?? models[0]
    }

    static func model(id: String) -> LocalModel? {
        models.first { $0.id == id }
    }

    static func migratedModelID(from selectedModelID: String) -> String {
        switch selectedModelID.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "", "gemma-4-e4b", "qwen-2.5-3b":
            return defaultModelID
        default:
            return selectedModelID
        }
    }
}
