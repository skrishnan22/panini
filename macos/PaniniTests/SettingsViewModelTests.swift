import XCTest
@testable import GrammarAI

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: UserSettings!
    private var launchAtLoginService: StubLaunchAtLoginService!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        settings = UserSettings(defaults: defaults)
        launchAtLoginService = StubLaunchAtLoginService()
    }

    private func makeViewModel(
        modelService: ModelManaging = StubModelService()
    ) -> SettingsViewModel {
        let permissionService = AccessibilityPermissionService()
        return SettingsViewModel(
            userSettings: settings,
            permissionService: permissionService,
            dictionaryService: StubDictionaryService(),
            modelService: modelService,
            launchAtLoginService: launchAtLoginService
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

    func testLaunchAtLoginUsesSystemServiceState() {
        settings.launchAtLogin = true
        launchAtLoginService.enabled = false

        let vm = makeViewModel()

        XCTAssertFalse(vm.launchAtLogin)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testSetLaunchAtLoginUpdatesSystemServiceAndSettings() {
        let vm = makeViewModel()

        vm.launchAtLogin = true

        XCTAssertTrue(launchAtLoginService.enabled)
        XCTAssertTrue(settings.launchAtLogin)
    }

    func testLaunchAtLoginFailureRevertsToggle() {
        launchAtLoginService.errorToThrow = StubLaunchAtLoginService.StubError.failed
        let vm = makeViewModel()

        vm.launchAtLogin = true

        XCTAssertFalse(vm.launchAtLogin)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(vm.lastError, "Could not update Launch at Login: failed")
    }

    func testDownloadModelPollsProgressWhileStartDownloadIsInFlight() async throws {
        let modelID = LocalModelCatalog.defaultModelID
        let modelService = BlockingDownloadModelService()
        let vm = makeViewModel(modelService: modelService)
        vm.models = [
            ModelEntry(
                id: modelID,
                name: "Qwen",
                params: "3B",
                ramGB: 3,
                downloadSizeGB: 2.0,
                isDefault: true,
                downloadStatus: .notDownloaded
            )
        ]

        let downloadTask = Task { await vm.downloadModel(modelID) }
        await modelService.waitUntilStartDownloadCalled()
        try await Task.sleep(nanoseconds: 1_200_000_000)

        let progressCallCount = await modelService.currentProgressCallCount()
        XCTAssertGreaterThan(progressCallCount, 0)

        await modelService.finishDownload()
        await downloadTask.value
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

private actor BlockingDownloadModelService: ModelManaging {
    private var didStartDownload = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var finishContinuation: CheckedContinuation<Void, Never>?
    private var progressCallCount = 0

    func fetchModelList() async throws -> [ModelListEntry] { [] }

    func fetchModelStatus(modelID: String) async throws -> ModelStatusResponse {
        ModelStatusResponse(modelID: modelID, status: didStartDownload ? .ready : .notDownloaded)
    }

    func startDownload(modelID: String) async throws {
        didStartDownload = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters = []

        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }
    }

    func fetchDownloadProgress(modelID: String) async throws -> DownloadProgressResponse {
        progressCallCount += 1
        return DownloadProgressResponse(
            modelID: modelID,
            status: "downloading",
            bytesDownloaded: 25,
            bytesTotal: 100,
            error: nil
        )
    }

    func cancelDownload(modelID: String) async throws {}
    func deleteModel(modelID: String) async throws {}

    func waitUntilStartDownloadCalled() async {
        if didStartDownload { return }

        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func finishDownload() {
        finishContinuation?.resume()
        finishContinuation = nil
    }

    func currentProgressCallCount() -> Int {
        progressCallCount
    }
}

private final class StubLaunchAtLoginService: LaunchAtLoginManaging, @unchecked Sendable {
    enum StubError: LocalizedError {
        case failed

        var errorDescription: String? { "failed" }
    }

    var enabled = false
    var errorToThrow: Error?

    var isEnabled: Bool { enabled }

    func setEnabled(_ enabled: Bool) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        self.enabled = enabled
    }
}
