import Foundation

@MainActor
final class DIContainer {
    static let shared = DIContainer()

    let config: AppConfig
    let serverProcessManager: ServerProcessManager
    let serverHealthClient: ServerHealthClient
    let correctionAPIClient: CorrectionAPIClient
    let accessibilityPermissionService: AccessibilityPermissionService
    let focusedTextReader: FocusedTextReader
    let focusedTextWriter: FocusedTextWriter
    let clipboardInserter: ClipboardSwapInserter
    let undoBuffer: UndoBuffer
    let reviewPanelController: ReviewPanelController
    let toastController: ToastController
    let dictionaryService: DictionaryService
    let coordinator: CorrectionCoordinator
    let settingsViewModel: SettingsViewModel

    private init() {
        let config = AppConfig()
        self.config = config

        let processManager = ServerProcessManager(config: config)
        self.serverProcessManager = processManager

        let healthClient = ServerHealthClient(baseURL: config.serverBaseURL, timeout: config.serverHealthTimeout)
        self.serverHealthClient = healthClient

        let apiClient = CorrectionAPIClient(baseURL: config.serverBaseURL, timeout: config.requestTimeout)
        self.correctionAPIClient = apiClient

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

        let dictionaryService = DictionaryService(baseURL: config.serverBaseURL, timeout: config.requestTimeout)
        self.dictionaryService = dictionaryService

        let coordinator = CorrectionCoordinator(
            config: config,
            serverManager: processManager,
            healthClient: healthClient,
            apiClient: apiClient,
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
            config: config,
            healthClient: healthClient,
            permissionService: permissionService,
            dictionaryService: dictionaryService
        )
        self.settingsViewModel = settingsViewModel
    }
}
