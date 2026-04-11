import Foundation

enum ModelDownloadStatus: String, Codable {
    case notDownloaded = "not_downloaded"
    case downloading
    case ready
}

struct ModelStatusResponse: Codable {
    let modelID: String
    let status: ModelDownloadStatus
    enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case status
    }
}

struct DownloadProgressResponse: Codable {
    let modelID: String
    let status: String
    let bytesDownloaded: Int?
    let bytesTotal: Int?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case status
        case bytesDownloaded = "bytes_downloaded"
        case bytesTotal = "bytes_total"
        case error
    }
}

struct ModelListEntry: Codable {
    let id: String
    let name: String
    let params: String
    let ramRequiredGB: Int
    let downloadSizeGB: Double
    let defaultFor: String?
    enum CodingKeys: String, CodingKey {
        case id, name, params
        case ramRequiredGB = "ram_required_gb"
        case downloadSizeGB = "download_size_gb"
        case defaultFor = "default_for"
    }
}

struct ModelManagementService {
    let baseURL: URL
    let timeout: TimeInterval
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval = 30, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = session
    }

    func fetchModelList() async throws -> [ModelListEntry] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaniniError.backendRequestFailed("Failed to fetch model list.")
        }
        struct ModelsResponse: Codable { let models: [ModelListEntry] }
        return try JSONDecoder().decode(ModelsResponse.self, from: data).models
    }

    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/status"))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaniniError.backendRequestFailed("Failed to fetch model status.")
        }
        return try JSONDecoder().decode(ModelStatusResponse.self, from: data)
    }

    func startDownload(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let sc = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(sc) else {
            throw PaniniError.backendRequestFailed("Failed to start model download.")
        }
    }

    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download/progress"))
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PaniniError.backendRequestFailed("Failed to fetch download progress.")
        }
        return try JSONDecoder().decode(DownloadProgressResponse.self, from: data)
    }

    func cancelDownload(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)/download/cancel"))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let sc = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(sc) else {
            throw PaniniError.backendRequestFailed("Failed to cancel download.")
        }
    }

    func deleteModel(modelID: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("models/\(modelID)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        let (_, response) = try await session.data(for: request)
        guard let sc = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(sc) else {
            throw PaniniError.backendRequestFailed("Failed to delete model.")
        }
    }
}
