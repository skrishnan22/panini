import Foundation

protocol ModelManaging {
    func fetchModelList() async throws -> [ModelListEntry]
    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse
    func startDownload(modelID: String) async throws
    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse
    func cancelDownload(modelID: String) async throws
    func deleteModel(modelID: String) async throws
}

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
