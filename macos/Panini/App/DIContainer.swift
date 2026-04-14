import Foundation

@MainActor
final class DIContainer {
    static let shared = DIContainer()

    let config: AppConfig
    let userSettings: UserSettings
    let accessibilityPermissionService: AccessibilityPermissionService
    let focusedTextReader: FocusedTextReader
    let focusedTextWriter: FocusedTextWriter
    let clipboardInserter: ClipboardSwapInserter
    let undoBuffer: UndoBuffer
    let reviewPanelController: ReviewPanelController
    let toastController: ToastController
    let dictionaryService: DictionaryManaging
    let modelManagementService: ModelManaging
    let mlxRuntime: MLXModelRuntime
    let correctionService: CorrectionServing
    let coordinator: CorrectionCoordinator
    let settingsViewModel: SettingsViewModel

    private init() {
        let config = AppConfig()
        self.config = config

        let userSettings = UserSettings()
        self.userSettings = userSettings

        let permissionService = AccessibilityPermissionService()
        self.accessibilityPermissionService = permissionService

        let frontmostApplicationProvider = DefaultFrontmostApplicationProvider()
        let applicationActivator = DefaultApplicationActivator()

        let reader = FocusedTextReader(provider: DefaultFocusedElementProvider.shared)
        self.focusedTextReader = reader

        let writer = FocusedTextWriter(provider: DefaultWritableFocusedElementProvider.shared)
        self.focusedTextWriter = writer

        let clipboardInserter = ClipboardSwapInserter()
        self.clipboardInserter = clipboardInserter

        let undo = UndoBuffer(ttlSeconds: config.undoWindowSeconds)
        self.undoBuffer = undo

        let reviewPanel = ReviewPanelController()
        self.reviewPanelController = reviewPanel

        let toast = ToastController()
        self.toastController = toast

        let dictionaryService = LocalDictionaryStore()
        self.dictionaryService = dictionaryService

        let modelsDirectory = try? PaniniDirectories.modelsDirectory()

        let mlxRuntime = MLXModelRuntime(modelsDirectory: modelsDirectory)
        self.mlxRuntime = mlxRuntime

        let modelService = LocalModelStore(loader: mlxRuntime, modelsDirectory: modelsDirectory)
        self.modelManagementService = modelService

        let localProvider = MLXLocalCorrectionProvider(
            userSettings: userSettings,
            dictionaryStore: dictionaryService,
            generator: mlxRuntime,
            readinessChecker: modelService
        )
        let correctionService = RoutingCorrectionService(
            userSettings: userSettings,
            localProvider: localProvider
        )
        self.correctionService = correctionService

        let coordinator = CorrectionCoordinator(
            config: config,
            apiClient: correctionService,
            frontmostApplicationProvider: frontmostApplicationProvider,
            applicationActivator: applicationActivator,
            textReader: reader,
            textWriter: writer,
            clipboardInserter: clipboardInserter,
            undoBuffer: undo,
            reviewPresenter: reviewPanel,
            toastPresenter: toast
        )
        self.coordinator = coordinator

        reviewPanel.applyHandler = { [weak coordinator] in
            Task { await coordinator?.applyReviewSelection() }
        }
        reviewPanel.cancelHandler = { [weak coordinator] in
            coordinator?.cancelReview()
        }
        reviewPanel.retryHandler = { [weak coordinator] in
            coordinator?.retryReview()
        }

        let settingsViewModel = SettingsViewModel(
            userSettings: userSettings,
            permissionService: permissionService,
            dictionaryService: dictionaryService,
            modelService: modelService
        )
        self.settingsViewModel = settingsViewModel

        settingsViewModel.onHotkeysChanged = {}  // Wired in AppDelegate
    }
}
