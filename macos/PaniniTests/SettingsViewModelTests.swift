import XCTest
@testable import GrammarAI

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        settings = UserSettings(defaults: defaults)
    }

    private func makeViewModel() -> SettingsViewModel {
        let permissionService = AccessibilityPermissionService()
        return SettingsViewModel(
            userSettings: settings,
            permissionService: permissionService,
            dictionaryService: StubDictionaryService(),
            modelService: StubModelService()
        )
    }

    func testDefaultPresetFromSettings() {
        settings.defaultPreset = "improve"
        let vm = makeViewModel()
        XCTAssertEqual(vm.selectedPreset, "improve")
    }

    func testSetPresetUpdatesSettings() {
        let vm = makeViewModel()
        vm.selectedPreset = "professional"
        XCTAssertEqual(settings.defaultPreset, "professional")
    }

    func testBackendChoiceFromSettings() {
        settings.backendChoice = .cloud
        let vm = makeViewModel()
        XCTAssertEqual(vm.backendChoice, .cloud)
        XCTAssertEqual(vm.providerStatus, "Cloud unavailable")
    }

    func testAvailablePresetsMatchesSelectionActions() {
        let vm = makeViewModel()
        let presetIDs = vm.availablePresets.map(\.id)
        XCTAssertEqual(presetIDs, ["fix", "improve", "professional", "casual", "paraphrase"])
    }

    func testHotkeyConflictDetection() {
        let vm = makeViewModel()
        vm.paletteHotkey = "cmd+shift+g"
        vm.fixHotkey = "cmd+shift+g"
        XCTAssertTrue(vm.hasHotkeyConflict)
    }

    func testNoHotkeyConflictWithDefaults() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasHotkeyConflict)
    }

    func testConnectionReportsCloudProviderUnavailable() async {
        let vm = makeViewModel()

        await vm.testConnection()

        XCTAssertEqual(vm.connectionTestStatus, .failed("Cloud provider is not configured yet."))
    }
}

private struct StubDictionaryService: DictionaryManaging {
    func listWords() async throws -> [String] { [] }
    func addWord(_ word: String) async throws {}
    func removeWord(_ word: String) async throws {}
}

private struct StubModelService: ModelManaging {
    func fetchModelList() async throws -> [ModelListEntry] { [] }
    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse {
        ModelStatusResponse(modelID: modelID, status: .notDownloaded)
    }
    func startDownload(modelID: String) async throws {}
    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        DownloadProgressResponse(modelID: modelID, status: "not_downloaded", bytesDownloaded: nil, bytesTotal: nil, error: nil)
    }
    func cancelDownload(modelID: String) async throws {}
    func deleteModel(modelID: String) async throws {}
}
