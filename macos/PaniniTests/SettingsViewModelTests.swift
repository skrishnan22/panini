import XCTest
@testable import GrammarAI

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        settings = UserSettings(defaults: defaults)
        session = makeMockSession()
    }

    private func makeViewModel() -> SettingsViewModel {
        let config = AppConfig()
        let healthClient = ServerHealthClient(baseURL: URL(string: "http://test")!, session: session)
        let permissionService = AccessibilityPermissionService()
        let dictionaryService = DictionaryService(baseURL: URL(string: "http://test")!, session: session)
        let modelService = ModelManagementService(baseURL: URL(string: "http://test")!, session: session)
        return SettingsViewModel(
            config: config, userSettings: settings, healthClient: healthClient,
            permissionService: permissionService, dictionaryService: dictionaryService,
            modelService: modelService
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
}
