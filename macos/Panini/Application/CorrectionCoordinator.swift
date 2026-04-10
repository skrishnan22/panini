import AppKit
import Foundation
import Combine

@MainActor
protocol ReviewPresenting: AnyObject {
    func present(session: ReviewSession)
    func dismiss()
}

@MainActor
protocol ToastPresenting: AnyObject {
    func show(message: String, actionTitle: String?, action: (() -> Void)?)
}

protocol FrontmostApplicationProviding {
    func frontmostProcessIdentifier() -> pid_t?
}

protocol ApplicationActivating {
    func activate(processIdentifier: pid_t)
}

struct DefaultFrontmostApplicationProvider: FrontmostApplicationProviding {
    func frontmostProcessIdentifier() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
}

struct DefaultApplicationActivator: ApplicationActivating {
    func activate(processIdentifier: pid_t) {
        NSRunningApplication(processIdentifier: processIdentifier)?
            .activate(options: [])
    }
}

@MainActor
final class CorrectionCoordinator: ObservableObject {
    @Published private(set) var activeReviewSession: ReviewSession?

    private let config: AppConfig
    private let serverManager: ServerControlling
    private let healthClient: ServerHealthChecking
    private let apiClient: CorrectionServing
    private let frontmostApplicationProvider: FrontmostApplicationProviding
    private let applicationActivator: ApplicationActivating
    private let textReader: TextReader
    private let textWriter: TextWriter
    private let clipboardInserter: ClipboardInserting
    private let undoBuffer: UndoManaging
    private weak var reviewPresenter: ReviewPresenting?
    private weak var toastPresenter: ToastPresenting?
    private var lastEditingSession: TextEditingSession?
    private var activeReviewTask: Task<Void, Never>?
    private var activeReviewRequestID: UUID?

    init(
        config: AppConfig,
        serverManager: ServerControlling,
        healthClient: ServerHealthChecking,
        apiClient: CorrectionServing,
        frontmostApplicationProvider: FrontmostApplicationProviding,
        applicationActivator: ApplicationActivating,
        textReader: TextReader,
        textWriter: TextWriter,
        clipboardInserter: ClipboardInserting,
        undoBuffer: UndoManaging,
        reviewPresenter: ReviewPresenting,
        toastPresenter: ToastPresenting
    ) {
        self.config = config
        self.serverManager = serverManager
        self.healthClient = healthClient
        self.apiClient = apiClient
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.applicationActivator = applicationActivator
        self.textReader = textReader
        self.textWriter = textWriter
        self.clipboardInserter = clipboardInserter
        self.undoBuffer = undoBuffer
        self.reviewPresenter = reviewPresenter
        self.toastPresenter = toastPresenter
    }

    func runReview() async {
        await runAction(.fix)
    }

    func runAction(_ action: SelectionAction) async {
        AppLogger.coordinator.info("runAction invoked action=\(action.rawValue, privacy: .public)")
        activeReviewTask?.cancel()
        activeReviewTask = nil
        activeReviewRequestID = nil
        let hadActiveReviewSession = activeReviewSession != nil
        activeReviewSession = nil
        if hadActiveReviewSession {
            reviewPresenter?.dismiss()
        }

        do {
            let targetProcessIdentifier = frontmostApplicationProvider.frontmostProcessIdentifier()
            let editingSession = try textReader.captureSession(targetProcessIdentifier: targetProcessIdentifier)
            AppLogger.coordinator.info(
                "Selection captured for action=\(action.rawValue, privacy: .public) chars=\(editingSession.selectedText.count)"
            )
            let session = ReviewSession(
                originalText: editingSession.selectedText,
                targetProcessIdentifier: editingSession.targetProcessIdentifier,
                editingSession: editingSession,
                phase: .loading,
                activeAction: action
            )

            activeReviewSession = session
            reviewPresenter?.present(session: session)
            AppLogger.coordinator.info(
                "Review loading session created action=\(action.rawValue, privacy: .public) chars=\(editingSession.selectedText.count)"
            )
            startReviewRequest(for: action, session: session, avoidOutputs: [])
        } catch {
            AppLogger.coordinator.error("runAction failed: \(error.localizedDescription, privacy: .public)")
            toastPresenter?.show(message: error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    func runAutofix() async {
        AppLogger.coordinator.info("runAutofix invoked")
        do {
            try await ensureServerReadyOrThrow()
        } catch is CancellationError {
            return
        } catch {
            AppLogger.coordinator.error("runAutofix aborted: server not ready")
            toastPresenter?.show(message: "Panini backend is unavailable.", actionTitle: nil, action: nil)
            return
        }

        do {
            let targetProcessIdentifier = frontmostApplicationProvider.frontmostProcessIdentifier()
            let editingSession = try textReader.captureSession(targetProcessIdentifier: targetProcessIdentifier)
            AppLogger.coordinator.info("Selection captured for autofix chars=\(editingSession.selectedText.count)")
            let result = try await apiClient.correct(
                text: editingSession.selectedText,
                mode: .autofix,
                preset: config.defaultPreset
            )
            AppLogger.coordinator.info("Autofix API completed changes=\(result.changes.count)")

            try applyText(result.corrected, session: editingSession)
            undoBuffer.push(previousText: editingSession.selectedText)
            AppLogger.coordinator.info("Autofix text applied chars=\(result.corrected.count)")

            let correctionCount = result.changes.count
            toastPresenter?.show(
                message: "\(correctionCount) corrections applied",
                actionTitle: "Undo",
                action: { [weak self] in
                    Task { await self?.undoLastAutofix() }
                }
            )
        } catch {
            AppLogger.coordinator.error("runAutofix failed: \(error.localizedDescription, privacy: .public)")
            toastPresenter?.show(message: error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    func applyReviewSelection() async {
        guard let session = activeReviewSession, session.canApply else { return }
        AppLogger.coordinator.info("applyReviewSelection invoked")

        do {
            reviewPresenter?.dismiss()
            if let targetProcessIdentifier = session.targetProcessIdentifier {
                applicationActivator.activate(processIdentifier: targetProcessIdentifier)
            }
            try applyText(session.previewText, session: session.editingSession)
            undoBuffer.push(previousText: session.originalText)
            AppLogger.coordinator.info("Review text applied chars=\(session.previewText.count)")
            activeReviewSession = nil
            toastPresenter?.show(
                message: "Applied review changes.",
                actionTitle: "Undo",
                action: { [weak self] in
                    Task { await self?.undoLastAutofix() }
                }
            )
        } catch {
            reviewPresenter?.present(session: session)
            AppLogger.coordinator.error("applyReviewSelection failed: \(error.localizedDescription, privacy: .public)")
            toastPresenter?.show(message: error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    func cancelReview() {
        if activeReviewSession?.phase == .loading {
            AppLogger.coordinator.info("Review request canceled")
        }

        activeReviewTask?.cancel()
        activeReviewTask = nil
        activeReviewRequestID = nil
        activeReviewSession = nil
        reviewPresenter?.dismiss()
    }

    func retryReview() {
        guard let session = activeReviewSession else { return }
        guard case .failed = session.phase else { return }
        let action = session.activeAction ?? .fix

        AppLogger.coordinator.info("Review retry started action=\(action.rawValue, privacy: .public)")
        startReviewRequest(for: action, session: session, avoidOutputs: [])
    }

    func regenerateCurrentOptions() async {
        guard let session = activeReviewSession else { return }
        guard let action = session.activeAction, action.reviewStyle == .rewriteVariants else { return }

        AppLogger.coordinator.info(
            "Regenerate requested action=\(action.rawValue, privacy: .public) prior_options=\(session.currentVariantTexts.count)"
        )
        startReviewRequest(for: action, session: session, avoidOutputs: session.currentVariantTexts)
    }

    func undoLastAutofix() async {
        AppLogger.coordinator.info("undoLastAutofix invoked")
        guard let previous = undoBuffer.popIfValid(now: Date()) else {
            AppLogger.coordinator.debug("undoLastAutofix skipped: no valid undo entry")
            toastPresenter?.show(message: "Undo window expired.", actionTitle: nil, action: nil)
            return
        }

        do {
            try applyText(previous, session: lastEditingSession)
            AppLogger.coordinator.info("Undo applied chars=\(previous.count)")
            toastPresenter?.show(message: "Undo complete.", actionTitle: nil, action: nil)
        } catch {
            AppLogger.coordinator.error("undoLastAutofix failed: \(error.localizedDescription, privacy: .public)")
            toastPresenter?.show(message: error.localizedDescription, actionTitle: nil, action: nil)
        }
    }

    private func startReviewRequest(for action: SelectionAction, session: ReviewSession, avoidOutputs: [String]) {
        activeReviewTask?.cancel()

        let requestID = UUID()
        activeReviewRequestID = requestID
        session.transitionToLoading(action: action)

        let reviewText = session.originalText

        activeReviewTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else { return }

            do {
                try await self.ensureServerReadyOrThrow()
                let response = try await self.apiClient.correct(
                    text: reviewText,
                    mode: .review,
                    preset: action.presetID,
                    avoidOutputs: avoidOutputs
                )

                guard self.activeReviewRequestID == requestID, self.activeReviewSession === session else { return }

                switch response {
                case let .single(result):
                    session.transitionToReady(result: result, action: action)
                    if case .empty = session.phase {
                        AppLogger.coordinator.info(
                            "Review request produced zero changes action=\(action.rawValue, privacy: .public)"
                        )
                    } else {
                        AppLogger.coordinator.info(
                            "Review request succeeded action=\(action.rawValue, privacy: .public) changes=\(session.changeCount)"
                        )
                    }
                case let .variants(payload):
                    if payload.variants.isEmpty {
                        session.transitionToEmpty(action: action)
                        AppLogger.coordinator.info(
                            "Review request produced zero variants action=\(action.rawValue, privacy: .public)"
                        )
                    } else {
                        session.transitionToVariants(action: action, variants: payload.variants)
                        AppLogger.coordinator.info(
                            "Review request succeeded action=\(action.rawValue, privacy: .public) variants=\(payload.variants.count)"
                        )
                    }
                }
                self.clearReviewRequestIfCurrent(requestID)
            } catch is CancellationError {
                guard self.activeReviewRequestID == requestID else { return }
                AppLogger.coordinator.info("Review request canceled")
                self.clearReviewRequestIfCurrent(requestID)
            } catch {
                guard self.activeReviewRequestID == requestID, self.activeReviewSession === session else { return }

                session.transitionToFailure(error.localizedDescription, action: action)
                AppLogger.coordinator.error("Review request failed: \(error.localizedDescription, privacy: .public)")
                self.clearReviewRequestIfCurrent(requestID)
            }
        }
    }

    private func clearReviewRequestIfCurrent(_ requestID: UUID) {
        guard activeReviewRequestID == requestID else { return }
        activeReviewTask = nil
        activeReviewRequestID = nil
    }

    private func ensureServerReadyOrThrow() async throws {
        if await healthClient.isHealthy() {
            AppLogger.coordinator.debug("Server already healthy; skipping process start")
            return
        }

        do {
            try serverManager.startIfNeeded()
        } catch {
            AppLogger.coordinator.error("Server start failed: \(error.localizedDescription, privacy: .public)")
            throw PaniniError.serverUnavailable
        }

        for _ in 0 ..< 8 {
            try Task.checkCancellation()
            if await healthClient.isHealthy() {
                AppLogger.coordinator.debug("Server reported healthy")
                return
            }
            try await Task.sleep(for: .milliseconds(200))
        }

        AppLogger.coordinator.error("Server health checks timed out")
        throw PaniniError.serverUnavailable
    }

    private func applyText(_ text: String, session: TextEditingSession?) throws {
        do {
            if let session {
                try textWriter.replaceSelection(in: session, with: text)
                lastEditingSession = session
            } else {
                try textWriter.replaceSelection(with: text)
                lastEditingSession = nil
            }
            AppLogger.coordinator.debug("AX text write succeeded")
        } catch {
            AppLogger.coordinator.error("AX text write failed, attempting clipboard fallback")
            do {
                try clipboardInserter.pasteReplacingSelection(
                    with: text,
                    targetProcessIdentifier: session?.targetProcessIdentifier
                )
                lastEditingSession = session
                AppLogger.coordinator.debug("Clipboard fallback paste succeeded")
            } catch {
                AppLogger.coordinator.error("Clipboard fallback paste failed")
                throw PaniniError.writeFailed
            }
        }
    }
}
