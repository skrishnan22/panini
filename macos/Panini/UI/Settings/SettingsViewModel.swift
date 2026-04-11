import Combine
import Foundation

struct PresetOption: Identifiable {
    let id: String
    let name: String
    let description: String
}

struct ModelEntry: Identifiable {
    let id: String
    let name: String
    let params: String
    let ramGB: Int
    let downloadSizeGB: Double
    let isDefault: Bool
    var downloadStatus: ModelDownloadStatus
    var downloadProgress: Double?
    var bytesDownloaded: Int?
    var bytesTotal: Int?
}

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - General
    @Published var selectedPreset: String {
        didSet { userSettings.defaultPreset = selectedPreset }
    }
    @Published var backendChoice: BackendChoice {
        didSet {
            userSettings.backendChoice = backendChoice
            onBackendOrModelChanged?()
        }
    }
    @Published var launchAtLogin: Bool {
        didSet { userSettings.launchAtLogin = launchAtLogin }
    }
    @Published var selectedModelID: String {
        didSet {
            userSettings.selectedModelID = selectedModelID
            onBackendOrModelChanged?()
        }
    }

    // MARK: - Status
    @Published var serverStatus: String = "Starting"
    @Published var accessibilityGranted: Bool = false

    // MARK: - Models
    @Published var models: [ModelEntry] = []
    @Published var totalDiskUsageLabel: String = "0 GB used by models"

    // MARK: - Cloud
    @Published var apiKey: String = "" {
        didSet { saveAPIKey() }
    }
    @Published var connectionTestStatus: ConnectionTestStatus = .untested

    enum ConnectionTestStatus: Equatable {
        case untested
        case testing
        case connected
        case failed(String)
    }

    // MARK: - Hotkeys
    @Published var paletteHotkey: String {
        didSet { userSettings.paletteHotkey = paletteHotkey; onHotkeysChanged?() }
    }
    @Published var fixHotkey: String {
        didSet { userSettings.fixHotkey = fixHotkey; onHotkeysChanged?() }
    }
    @Published var paraphraseHotkey: String {
        didSet { userSettings.paraphraseHotkey = paraphraseHotkey; onHotkeysChanged?() }
    }
    @Published var professionalHotkey: String {
        didSet { userSettings.professionalHotkey = professionalHotkey; onHotkeysChanged?() }
    }

    var hasHotkeyConflict: Bool {
        let all = [paletteHotkey, fixHotkey, paraphraseHotkey, professionalHotkey]
        return Set(all).count != all.count
    }

    // MARK: - Dictionary
    @Published var dictionaryWords: [String] = []
    @Published var newDictionaryWord: String = ""
    @Published var lastError: String?

    // MARK: - Callbacks
    var onBackendOrModelChanged: (() -> Void)?
    var onHotkeysChanged: (() -> Void)?

    // MARK: - Dependencies
    private let config: AppConfig
    private let userSettings: UserSettings
    private let healthClient: ServerHealthChecking
    private let permissionService: AccessibilityPermissionService
    private let dictionaryService: DictionaryService
    private let modelService: ModelManagementService
    private var downloadPollTimer: Timer?

    let availablePresets: [PresetOption] = [
        PresetOption(id: "fix", name: "Fix", description: "Correct grammar and spelling"),
        PresetOption(id: "improve", name: "Improve", description: "Polish clarity and flow"),
        PresetOption(id: "professional", name: "Professional", description: "Rewrite in a professional tone"),
        PresetOption(id: "casual", name: "Casual", description: "Make the tone more casual"),
        PresetOption(id: "paraphrase", name: "Paraphrase", description: "Generate rewrite variants"),
    ]

    let hotkeyOptions: [String] = [
        "cmd+shift+g", "cmd+shift+r", "ctrl+shift+g", "cmd+shift+;",
        "cmd+shift+option+g", "cmd+shift+option+r", "ctrl+shift+option+g",
        "cmd+shift+option+f", "ctrl+shift+f",
        "cmd+shift+option+p", "cmd+shift+option+h", "ctrl+shift+p",
        "cmd+shift+option+m", "cmd+shift+option+j", "ctrl+shift+m",
    ]

    init(
        config: AppConfig,
        userSettings: UserSettings,
        healthClient: ServerHealthChecking,
        permissionService: AccessibilityPermissionService,
        dictionaryService: DictionaryService,
        modelService: ModelManagementService
    ) {
        self.config = config
        self.userSettings = userSettings
        self.healthClient = healthClient
        self.permissionService = permissionService
        self.dictionaryService = dictionaryService
        self.modelService = modelService

        self.selectedPreset = userSettings.defaultPreset
        self.backendChoice = userSettings.backendChoice
        self.launchAtLogin = userSettings.launchAtLogin
        self.selectedModelID = userSettings.selectedModelID
        self.paletteHotkey = userSettings.paletteHotkey
        self.fixHotkey = userSettings.fixHotkey
        self.paraphraseHotkey = userSettings.paraphraseHotkey
        self.professionalHotkey = userSettings.professionalHotkey
        self.accessibilityGranted = permissionService.isGranted()
        loadAPIKey()
    }

    // MARK: - Status
    func refreshServerHealth() async {
        let healthy = await healthClient.isHealthy()
        serverStatus = healthy ? "Healthy" : "Error"
    }

    func refreshPermission() {
        accessibilityGranted = permissionService.isGranted()
    }

    func requestAccessibilityPermission() {
        permissionService.requestIfNeeded()
        refreshPermission()
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    // MARK: - Models
    func loadModels() async {
        do {
            let response = try await modelService.fetchModelList()
            var entries: [ModelEntry] = []
            for model in response {
                let statusResponse = try await modelService.fetchModelStatus(modelID: model.id)
                entries.append(ModelEntry(
                    id: model.id, name: model.name, params: model.params,
                    ramGB: model.ramRequiredGB, downloadSizeGB: model.downloadSizeGB,
                    isDefault: model.defaultFor == "mlx",
                    downloadStatus: statusResponse.status
                ))
            }
            models = entries
        } catch {
            lastError = error.localizedDescription
        }
    }

    func downloadModel(_ modelID: String) async {
        do {
            try await modelService.startDownload(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .downloading
            }
            startPollingProgress(modelID: modelID)
        } catch { lastError = error.localizedDescription }
    }

    func cancelDownload(_ modelID: String) async {
        do {
            try await modelService.cancelDownload(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .notDownloaded
                models[index].downloadProgress = nil
            }
            stopPollingProgress()
        } catch { lastError = error.localizedDescription }
    }

    func deleteModel(_ modelID: String) async {
        do {
            try await modelService.deleteModel(modelID: modelID)
            if let index = models.firstIndex(where: { $0.id == modelID }) {
                models[index].downloadStatus = .notDownloaded
            }
        } catch { lastError = error.localizedDescription }
    }

    private func startPollingProgress(modelID: String) {
        stopPollingProgress()
        downloadPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.pollProgress(modelID: modelID) }
        }
    }

    private func stopPollingProgress() {
        downloadPollTimer?.invalidate()
        downloadPollTimer = nil
    }

    private func pollProgress(modelID: String) async {
        do {
            let progress = try await modelService.fetchDownloadProgress(modelID: modelID)
            guard let index = models.firstIndex(where: { $0.id == modelID }) else { return }
            if progress.status == "ready" || progress.status == "not_downloaded" {
                models[index].downloadStatus = ModelDownloadStatus(rawValue: progress.status) ?? .notDownloaded
                models[index].downloadProgress = nil
                stopPollingProgress()
            } else if progress.status == "downloading" {
                models[index].downloadStatus = .downloading
                models[index].bytesDownloaded = progress.bytesDownloaded
                models[index].bytesTotal = progress.bytesTotal
                if let dl = progress.bytesDownloaded, let total = progress.bytesTotal, total > 0 {
                    models[index].downloadProgress = Double(dl) / Double(total)
                }
            } else if progress.status == "failed" {
                models[index].downloadStatus = .notDownloaded
                models[index].downloadProgress = nil
                lastError = progress.error ?? "Download failed."
                stopPollingProgress()
            }
        } catch { stopPollingProgress() }
    }

    var hasAnyModelDownloaded: Bool {
        models.contains { $0.downloadStatus == .ready }
    }

    // MARK: - Cloud
    func testConnection() async {
        connectionTestStatus = .testing
        let healthy = await healthClient.isHealthy()
        connectionTestStatus = healthy ? .connected : .failed("Could not connect to backend.")
    }

    private func loadAPIKey() {
        apiKey = KeychainService.retrieve(account: KeychainService.apiKeyAccount) ?? ""
    }

    private func saveAPIKey() {
        if apiKey.isEmpty {
            KeychainService.delete(account: KeychainService.apiKeyAccount)
        } else {
            try? KeychainService.save(account: KeychainService.apiKeyAccount, data: apiKey)
        }
    }

    // MARK: - Dictionary
    func loadDictionary() async {
        do {
            dictionaryWords = try await dictionaryService.listWords()
            lastError = nil
        } catch { lastError = error.localizedDescription }
    }

    func addDictionaryWord() async {
        let word = newDictionaryWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        do {
            try await dictionaryService.addWord(word)
            newDictionaryWord = ""
            await loadDictionary()
        } catch { lastError = error.localizedDescription }
    }

    func removeDictionaryWord(_ word: String) async {
        do {
            try await dictionaryService.removeWord(word)
            await loadDictionary()
        } catch { lastError = error.localizedDescription }
    }

    // MARK: - Hotkeys
    func resetHotkeysToDefaults() {
        paletteHotkey = "cmd+shift+g"
        fixHotkey = "cmd+shift+option+g"
        paraphraseHotkey = "cmd+shift+option+p"
        professionalHotkey = "cmd+shift+option+m"
    }
}
