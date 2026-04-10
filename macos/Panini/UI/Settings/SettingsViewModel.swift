import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var backendLabel: String = "Localhost"
    @Published var preset: String
    @Published var reviewHotkey: String = "Cmd+Shift+G"
    @Published var autofixHotkey: String = "Cmd+Shift+Option+G"
    @Published var serverStatus: String = "Starting"
    @Published var accessibilityGranted: Bool = false
    @Published var dictionaryWords: [String] = []
    @Published var newDictionaryWord: String = ""
    @Published var lastError: String?

    private let config: AppConfig
    private let healthClient: ServerHealthChecking
    private let permissionService: AccessibilityPermissionService
    private let dictionaryService: DictionaryService

    init(
        config: AppConfig,
        healthClient: ServerHealthChecking,
        permissionService: AccessibilityPermissionService,
        dictionaryService: DictionaryService
    ) {
        self.config = config
        self.healthClient = healthClient
        self.permissionService = permissionService
        self.dictionaryService = dictionaryService
        self.preset = config.defaultPreset
        self.accessibilityGranted = permissionService.isGranted()
    }

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

    func loadDictionary() async {
        do {
            dictionaryWords = try await dictionaryService.listWords()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addDictionaryWord() async {
        let word = newDictionaryWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }

        do {
            try await dictionaryService.addWord(word)
            newDictionaryWord = ""
            await loadDictionary()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeDictionaryWord(_ word: String) async {
        do {
            try await dictionaryService.removeWord(word)
            await loadDictionary()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
