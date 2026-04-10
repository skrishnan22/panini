import XCTest
@testable import GrammarAI

private final class MockServerManager: ServerControlling {
    var shouldThrow = false
    var starts = 0

    func startIfNeeded() throws {
        starts += 1
        if shouldThrow { throw GrammarAIError.serverUnavailable }
    }

    func stop() {}
}

private struct MockHealthClient: ServerHealthChecking {
    let healthy: Bool
    func isHealthy() async -> Bool { healthy }
}

private struct MockAPIClient: CorrectionServing {
    let response: CorrectionResponse

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        guard case let .single(result) = response else {
            throw GrammarAIError.backendRequestFailed("Expected a single correction payload.")
        }
        return result
    }

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        response
    }
}

private final class ControllableAPIClient: CorrectionServing {
    private struct PendingRequest {
        let id: UUID
        let text: String
        let mode: CorrectionMode
        let preset: String
        let avoidOutputs: [String]
        let continuation: CheckedContinuation<CorrectionResponse, Error>
    }

    private let lock = NSLock()
    private var pendingRequests: [PendingRequest] = []

    private var requestedTextsStorage: [String] = []
    private var requestedModesStorage: [CorrectionMode] = []
    private var requestedPresetsStorage: [String] = []
    private var requestedAvoidOutputsStorage: [[String]] = []
    private var cancellationCountStorage = 0

    func correct(text: String, mode: CorrectionMode, preset: String) async throws -> CorrectionResult {
        let response = try await correct(text: text, mode: mode, preset: preset, avoidOutputs: [])
        guard case let .single(result) = response else {
            throw GrammarAIError.backendRequestFailed("Expected a single correction payload.")
        }
        return result
    }

    func correct(
        text: String,
        mode: CorrectionMode,
        preset: String,
        avoidOutputs: [String]
    ) async throws -> CorrectionResponse {
        let id = UUID()
        recordRequest(text: text, mode: mode, preset: preset, avoidOutputs: avoidOutputs)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                storePendingRequest(
                    PendingRequest(
                        id: id,
                        text: text,
                        mode: mode,
                        preset: preset,
                        avoidOutputs: avoidOutputs,
                        continuation: continuation
                    )
                )
            }
        } onCancel: {
            self.cancelPendingRequest(id: id)
        }
    }

    func succeedNext(with result: CorrectionResponse) {
        resumeNext(with: .success(result))
    }

    func failNext(with error: Error) {
        resumeNext(with: .failure(error))
    }

    var hasPendingRequest: Bool {
        lock.withLock { !pendingRequests.isEmpty }
    }

    var requestedTexts: [String] {
        lock.withLock { requestedTextsStorage }
    }

    var lastAvoidOutputs: [String] {
        lock.withLock { requestedAvoidOutputsStorage.last ?? [] }
    }

    var cancellationCount: Int {
        lock.withLock { cancellationCountStorage }
    }

    private func recordRequest(text: String, mode: CorrectionMode, preset: String, avoidOutputs: [String]) {
        lock.withLock {
            requestedTextsStorage.append(text)
            requestedModesStorage.append(mode)
            requestedPresetsStorage.append(preset)
            requestedAvoidOutputsStorage.append(avoidOutputs)
        }
    }

    private func storePendingRequest(_ request: PendingRequest) {
        lock.withLock {
            pendingRequests.append(request)
        }
    }

    private func cancelPendingRequest(id: UUID) {
        let continuation: CheckedContinuation<CorrectionResponse, Error>? = lock.withLock {
            guard let index = pendingRequests.firstIndex(where: { $0.id == id }) else { return nil }
            cancellationCountStorage += 1
            return pendingRequests.remove(at: index).continuation
        }

        continuation?.resume(throwing: CancellationError())
    }

    private func resumeNext(with result: Result<CorrectionResponse, Error>) {
        let continuation: CheckedContinuation<CorrectionResponse, Error>? = lock.withLock {
            guard !pendingRequests.isEmpty else { return nil }
            return pendingRequests.removeFirst().continuation
        }

        switch result {
        case let .success(value):
            continuation?.resume(returning: value)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }
}

private struct MockFrontmostApplicationProvider: FrontmostApplicationProviding {
    let processIdentifier: pid_t?
    func frontmostProcessIdentifier() -> pid_t? { processIdentifier }
}

private final class MockApplicationActivator: ApplicationActivating {
    var activations: [pid_t] = []

    func activate(processIdentifier: pid_t) {
        activations.append(processIdentifier)
    }
}

private final class MockTextReader: TextReader {
    private var sessions: [TextEditingSession]

    init(selected: String, session: TextEditingSession? = nil) {
        self.sessions = [session ?? MockTextReader.makeSession(selected: selected, targetProcessIdentifier: nil)]
    }

    init(sessions: [TextEditingSession]) {
        self.sessions = sessions
    }

    func currentSelection() throws -> String {
        sessions.first?.selectedText ?? ""
    }

    func captureSession(targetProcessIdentifier: pid_t?) throws -> TextEditingSession {
        guard !sessions.isEmpty else {
            throw GrammarAIError.selectionUnavailable
        }

        let session = sessions.removeFirst()
        return TextEditingSession(
            targetProcessIdentifier: session.targetProcessIdentifier ?? targetProcessIdentifier,
            element: session.element,
            capabilities: session.capabilities,
            selectedText: session.selectedText,
            selectedRange: session.selectedRange,
            fullValue: session.fullValue,
            readStrategy: session.readStrategy,
            writeStrategy: session.writeStrategy
        )
    }

    private static func makeSession(selected: String, targetProcessIdentifier: pid_t?) -> TextEditingSession {
        TextEditingSession(
            targetProcessIdentifier: targetProcessIdentifier,
            element: MockAXCapabilityElement(
                attributes: [kAXSelectedTextAttribute as String: selected as NSString],
                attributeNames: [kAXSelectedTextAttribute as String],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: selected,
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )
    }
}

private final class MockTextWriter: TextWriter {
    var shouldFail = false
    var writes: [String] = []
    var sessionWrites: [String] = []
    var beforeWrite: (() -> Void)?

    func replaceSelection(with text: String) throws {
        if shouldFail { throw GrammarAIError.writeFailed }
        beforeWrite?()
        writes.append(text)
    }

    func replaceSelection(in session: TextEditingSession, with text: String) throws {
        if shouldFail { throw GrammarAIError.writeFailed }
        beforeWrite?()
        sessionWrites.append(text)
    }
}

private final class MockClipboardInserter: ClipboardInserting {
    var shouldFail = false
    var writes: [String] = []
    var targetProcessIdentifiers: [pid_t?] = []

    func pasteReplacingSelection(with text: String, targetProcessIdentifier: pid_t?) throws {
        if shouldFail { throw GrammarAIError.writeFailed }
        writes.append(text)
        targetProcessIdentifiers.append(targetProcessIdentifier)
    }
}

private final class MockUndoBuffer: UndoManaging {
    var pushed: [String] = []
    var popValue: String?

    func push(previousText: String) {
        pushed.append(previousText)
    }

    func popIfValid(now: Date) -> String? {
        defer { popValue = nil }
        return popValue
    }
}

@MainActor
private final class MockReviewPresenter: ReviewPresenting {
    var presented: ReviewSession?
    var dismisses = 0

    func present(session: ReviewSession) {
        presented = session
    }

    func dismiss() {
        dismisses += 1
    }
}

@MainActor
private final class MockToastPresenter: ToastPresenting {
    var messages: [String] = []
    var lastAction: (() -> Void)?

    func show(message: String, actionTitle: String?, action: (() -> Void)?) {
        messages.append(message)
        lastAction = action
    }
}

@MainActor
final class CorrectionCoordinatorTests: XCTestCase {
    private func makeResult(original: String = "i has a error", corrected: String = "I have an error") -> CorrectionResult {
        CorrectionResult(
            original: original,
            corrected: corrected,
            changes: [
                Change(offsetStart: 0, offsetEnd: 1, originalText: "i", replacement: "I", category: .grammar),
                Change(offsetStart: 2, offsetEnd: 7, originalText: "has a", replacement: "have an", category: .grammar),
            ],
            modelUsed: "gemma-4-e4b",
            backendUsed: "mlx"
        )
    }

    private func makeVariantPayload(original: String = "follow up") -> VariantCorrectionPayload {
        VariantCorrectionPayload(
            original: original,
            variants: [
                RewriteVariant(
                    id: "variant-1",
                    label: "Recommended",
                    text: "Hello, I am following up.",
                    isRecommended: true
                ),
                RewriteVariant(
                    id: "variant-2",
                    label: "Alternative",
                    text: "Just checking in on this.",
                    isRecommended: false
                ),
            ],
            modelUsed: "gemma-4-e4b",
            backendUsed: "mlx"
        )
    }

    func testReviewModeReadsCallsServerAndPublishesReviewSession() async {
        let dependencies = makeDependencies(apiClient: ControllableAPIClient())

        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.reviewPresenter.presented?.phase == .loading }

        XCTAssertEqual(dependencies.coordinator.activeReviewSession?.phase, .loading)
        XCTAssertTrue((dependencies.apiClient as? ControllableAPIClient)?.hasPendingRequest == true)
        XCTAssertEqual(dependencies.server.starts, 0)
    }

    func testRunReviewStoresCapturedSessionOnReviewSession() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()
        let frontmostProvider = MockFrontmostApplicationProvider(processIdentifier: 42)
        let editingSession = TextEditingSession(
            targetProcessIdentifier: 42,
            element: MockAXCapabilityElement(),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: "i has a error",
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: frontmostProvider,
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error", session: editingSession),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runReview()

        XCTAssertEqual(reviewPresenter.presented?.targetProcessIdentifier, 42)
        XCTAssertEqual(reviewPresenter.presented?.editingSession?.selectedText, "i has a error")
    }

    func testSuccessfulReviewTransitionsLoadingToReady() async throws {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(apiClient: apiClient)
        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        await waitUntil { apiClient.hasPendingRequest }
        apiClient.succeedNext(with: .single(makeResult()))
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .ready }

        let session = try XCTUnwrap(dependencies.coordinator.activeReviewSession)
        XCTAssertEqual(session.previewText, "I have an error")
        XCTAssertEqual(session.changeCount, 2)
    }

    func testZeroChangeReviewTransitionsLoadingToEmpty() async {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(
            apiClient: apiClient,
            textReader: MockTextReader(selected: "Looks fine")
        )
        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        await waitUntil { apiClient.hasPendingRequest }
        apiClient.succeedNext(with: .single(CorrectionResult(
            original: "Looks fine",
            corrected: "Looks fine",
            changes: [],
            modelUsed: "gemma-4-e4b",
            backendUsed: "mlx"
        )))
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .empty }

        XCTAssertEqual(dependencies.coordinator.activeReviewSession?.previewText, "Looks fine")
    }

    func testServerFailureAfterPresentationTransitionsLoadingToFailed() async {
        let dependencies = makeDependencies(
            serverManager: {
                let manager = MockServerManager()
                manager.shouldThrow = true
                return manager
            }(),
            healthClient: MockHealthClient(healthy: false),
            apiClient: ControllableAPIClient()
        )

        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .failed(message: GrammarAIError.serverUnavailable.localizedDescription ?? "") }

        XCTAssertEqual(dependencies.reviewPresenter.presented?.phase, .failed(message: GrammarAIError.serverUnavailable.localizedDescription ?? ""))
        XCTAssertTrue(dependencies.toastPresenter.messages.isEmpty)
    }

    func testCancelDuringLoadingCancelsTaskAndDismissesPanel() async {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(apiClient: apiClient)
        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        dependencies.coordinator.cancelReview()
        await waitUntil { dependencies.reviewPresenter.dismisses == 1 }

        XCTAssertNil(dependencies.coordinator.activeReviewSession)
        XCTAssertEqual(apiClient.cancellationCount, 1)
        XCTAssertTrue(dependencies.toastPresenter.messages.isEmpty)
    }

    func testRetryFromFailedStateTransitionsBackToLoadingAndThenReady() async {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(apiClient: apiClient)
        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        await waitUntil { apiClient.hasPendingRequest }
        apiClient.failNext(with: GrammarAIError.backendRequestFailed("Backend returned status 500."))
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .failed(message: "Backend returned status 500.") }

        let sessionBeforeRetry = dependencies.coordinator.activeReviewSession
        dependencies.coordinator.retryReview()
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        XCTAssertTrue(sessionBeforeRetry === dependencies.coordinator.activeReviewSession)

        await waitUntil { apiClient.hasPendingRequest }
        apiClient.succeedNext(with: .single(makeResult()))
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .ready }
    }

    func testSecondRunReviewCancelsFirstInFlightTask() async {
        let apiClient = ControllableAPIClient()
        let firstSession = TextEditingSession(
            targetProcessIdentifier: 1,
            element: MockAXCapabilityElement(),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: "first text",
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )
        let secondSession = TextEditingSession(
            targetProcessIdentifier: 2,
            element: MockAXCapabilityElement(),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: "second text",
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )
        let dependencies = makeDependencies(
            apiClient: apiClient,
            textReader: MockTextReader(sessions: [firstSession, secondSession])
        )

        let firstTask = Task { await dependencies.coordinator.runReview() }
        await waitUntil { apiClient.requestedTexts.count == 1 }
        await waitUntil { apiClient.hasPendingRequest }

        let secondTask = Task { await dependencies.coordinator.runReview() }
        defer {
            firstTask.cancel()
            secondTask.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { apiClient.requestedTexts.count == 2 }
        XCTAssertEqual(apiClient.cancellationCount, 1)
        XCTAssertEqual(dependencies.coordinator.activeReviewSession?.originalText, "second text")
    }

    func testCancellationDoesNotSurfaceAsErrorToast() async {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(apiClient: apiClient)
        let task = Task { await dependencies.coordinator.runReview() }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .loading }
        dependencies.coordinator.cancelReview()
        await waitUntil { apiClient.cancellationCount == 1 }

        XCTAssertTrue(dependencies.toastPresenter.messages.isEmpty)
    }

    func testAutofixModeWritesImmediatelyAndStoresUndo() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: MockFrontmostApplicationProvider(processIdentifier: nil),
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error"),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runAutofix()

        XCTAssertEqual(writer.sessionWrites, ["I have an error"])
        XCTAssertEqual(undo.pushed, ["i has a error"])
    }

    func testFailedAXWriteFallsBackToClipboard() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        writer.shouldFail = true

        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: MockFrontmostApplicationProvider(processIdentifier: nil),
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error"),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runAutofix()

        XCTAssertEqual(clipboard.writes, ["I have an error"])
        XCTAssertEqual(clipboard.targetProcessIdentifiers, [nil])
    }

    func testAutofixDoesNotStoreUndoWhenWriteAndClipboardFallbackFail() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        writer.shouldFail = true

        let clipboard = MockClipboardInserter()
        clipboard.shouldFail = true

        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: MockFrontmostApplicationProvider(processIdentifier: nil),
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error"),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runAutofix()

        XCTAssertTrue(undo.pushed.isEmpty)
        XCTAssertEqual(toastPresenter.messages.last, GrammarAIError.writeFailed.localizedDescription)
    }

    func testApplyReviewDismissesPanelAndReactivatesOriginalAppBeforeWriting() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()
        let frontmostProvider = MockFrontmostApplicationProvider(processIdentifier: 42)

        writer.beforeWrite = {
            XCTAssertEqual(reviewPresenter.dismisses, 1)
            XCTAssertEqual(activator.activations, [42])
        }

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: frontmostProvider,
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error"),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runReview()
        await waitUntil { coordinator.activeReviewSession?.phase == .ready }
        await coordinator.applyReviewSelection()

        XCTAssertEqual(writer.sessionWrites, ["I have an error"])
        XCTAssertEqual(reviewPresenter.dismisses, 1)
        XCTAssertEqual(activator.activations, [42])
    }

    func testApplyReviewClipboardFallbackTargetsOriginalApplication() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        writer.shouldFail = true

        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()
        let frontmostProvider = MockFrontmostApplicationProvider(processIdentifier: 42)
        let editingSession = TextEditingSession(
            targetProcessIdentifier: 42,
            element: MockAXCapabilityElement(),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: "i has a error",
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: frontmostProvider,
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error", session: editingSession),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runReview()
        await waitUntil { coordinator.activeReviewSession?.phase == .ready }
        await coordinator.applyReviewSelection()

        XCTAssertEqual(reviewPresenter.dismisses, 1)
        XCTAssertEqual(activator.activations, [42])
        XCTAssertEqual(clipboard.writes, ["I have an error"])
        XCTAssertEqual(clipboard.targetProcessIdentifiers, [42])
    }

    func testApplyReviewDoesNotStoreUndoWhenWriteAndClipboardFallbackFail() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        writer.shouldFail = true

        let clipboard = MockClipboardInserter()
        clipboard.shouldFail = true

        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: MockFrontmostApplicationProvider(processIdentifier: 42),
            applicationActivator: activator,
            textReader: MockTextReader(selected: "i has a error"),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runReview()
        await waitUntil { coordinator.activeReviewSession?.phase == .ready }
        await coordinator.applyReviewSelection()

        XCTAssertTrue(undo.pushed.isEmpty)
        XCTAssertNotNil(coordinator.activeReviewSession)
        XCTAssertEqual(toastPresenter.messages.last, GrammarAIError.writeFailed.localizedDescription)
    }

    func testRunActionWithVariantsSelectsRecommendedOptionByDefault() async throws {
        let apiClient = ControllableAPIClient()
        let dependencies = makeDependencies(
            apiClient: apiClient,
            textReader: MockTextReader(selected: "follow up")
        )

        let task = Task { await dependencies.coordinator.runAction(.professional) }
        defer {
            task.cancel()
            dependencies.coordinator.cancelReview()
        }

        await waitUntil { apiClient.hasPendingRequest }
        apiClient.succeedNext(with: .variants(makeVariantPayload()))
        await waitUntil { dependencies.coordinator.activeReviewSession?.phase == .ready }

        let session = try XCTUnwrap(dependencies.coordinator.activeReviewSession)
        XCTAssertEqual(session.previewText, "Hello, I am following up.")
        XCTAssertEqual(session.activeAction, .professional)
    }

    func testRegenerateForwardsVisibleVariantsAsAvoidOutputs() async {
        let api = ControllableAPIClient()
        let coordinator = makeDependencies(
            apiClient: api,
            textReader: MockTextReader(selected: "follow up")
        ).coordinator

        let initialTask = Task { await coordinator.runAction(.professional) }
        defer {
            initialTask.cancel()
            coordinator.cancelReview()
        }

        await waitUntil { api.hasPendingRequest }
        api.succeedNext(with: .variants(makeVariantPayload()))
        await waitUntil { coordinator.activeReviewSession?.phase == .ready }

        let regenerateTask = Task { await coordinator.regenerateCurrentOptions() }
        defer { regenerateTask.cancel() }

        await waitUntil { api.requestedTexts.count == 2 }
        XCTAssertEqual(api.lastAvoidOutputs, ["Hello, I am following up.", "Just checking in on this."])
    }

    func testRunActionCaptureFailureDismissesExistingReviewSession() async {
        let server = MockServerManager()
        let writer = MockTextWriter()
        let clipboard = MockClipboardInserter()
        let undo = MockUndoBuffer()
        let reviewPresenter = MockReviewPresenter()
        let toastPresenter = MockToastPresenter()
        let activator = MockApplicationActivator()

        let firstSession = TextEditingSession(
            targetProcessIdentifier: 42,
            element: MockAXCapabilityElement(),
            capabilities: AXElementCapabilities(
                supportedAttributes: [kAXSelectedTextAttribute as String],
                supportedParameterizedAttributes: [],
                settableAttributes: [kAXSelectedTextAttribute as String]
            ),
            selectedText: "i has a error",
            selectedRange: nil,
            fullValue: nil,
            readStrategy: .selectedTextAttribute,
            writeStrategy: .selectedTextAttribute
        )

        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: server,
            healthClient: MockHealthClient(healthy: true),
            apiClient: MockAPIClient(response: .single(makeResult())),
            frontmostApplicationProvider: MockFrontmostApplicationProvider(processIdentifier: 42),
            applicationActivator: activator,
            textReader: MockTextReader(sessions: [firstSession]),
            textWriter: writer,
            clipboardInserter: clipboard,
            undoBuffer: undo,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        await coordinator.runReview()
        await waitUntil { coordinator.activeReviewSession?.phase == .ready }

        await coordinator.runAction(.professional)

        XCTAssertNil(coordinator.activeReviewSession)
        XCTAssertEqual(reviewPresenter.dismisses, 1)
        XCTAssertEqual(toastPresenter.messages.last, GrammarAIError.selectionUnavailable.localizedDescription)
    }

    private func makeDependencies(
        serverManager: MockServerManager = MockServerManager(),
        healthClient: MockHealthClient = MockHealthClient(healthy: true),
        apiClient: CorrectionServing = MockAPIClient(response: .single(CorrectionResult(
            original: "i has a error",
            corrected: "I have an error",
            changes: [
                Change(offsetStart: 0, offsetEnd: 1, originalText: "i", replacement: "I", category: .grammar),
                Change(offsetStart: 2, offsetEnd: 7, originalText: "has a", replacement: "have an", category: .grammar),
            ],
            modelUsed: "gemma-4-e4b",
            backendUsed: "mlx"
        ))),
        frontmostApplicationProvider: FrontmostApplicationProviding = MockFrontmostApplicationProvider(processIdentifier: nil),
        applicationActivator: MockApplicationActivator = MockApplicationActivator(),
        textReader: TextReader = MockTextReader(selected: "i has a error"),
        textWriter: MockTextWriter = MockTextWriter(),
        clipboardInserter: MockClipboardInserter = MockClipboardInserter(),
        undoBuffer: MockUndoBuffer = MockUndoBuffer(),
        reviewPresenter: MockReviewPresenter? = nil,
        toastPresenter: MockToastPresenter? = nil
    ) -> (
        coordinator: CorrectionCoordinator,
        server: MockServerManager,
        apiClient: CorrectionServing,
        reviewPresenter: MockReviewPresenter,
        toastPresenter: MockToastPresenter
    ) {
        let reviewPresenter = reviewPresenter ?? MockReviewPresenter()
        let toastPresenter = toastPresenter ?? MockToastPresenter()
        let coordinator = CorrectionCoordinator(
            config: AppConfig(),
            serverManager: serverManager,
            healthClient: healthClient,
            apiClient: apiClient,
            frontmostApplicationProvider: frontmostApplicationProvider,
            applicationActivator: applicationActivator,
            textReader: textReader,
            textWriter: textWriter,
            clipboardInserter: clipboardInserter,
            undoBuffer: undoBuffer,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )

        return (
            coordinator: coordinator,
            server: serverManager,
            apiClient: apiClient,
            reviewPresenter: reviewPresenter,
            toastPresenter: toastPresenter
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

        while !predicate() {
            if DispatchTime.now().uptimeNanoseconds > deadline {
                XCTFail("Timed out waiting for condition.", file: file, line: line)
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
