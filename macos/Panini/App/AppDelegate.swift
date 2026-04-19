import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let container = DIContainer.shared
    private let hotkeyManager = GlobalHotkeyManager()
    private let commandPaletteController = CommandPaletteController()
    private let commandPaletteActions: [SelectionAction] = [.fix, .paraphrase, .professional, .improve, .casual]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerHotkeys()

        container.settingsViewModel.onHotkeysChanged = { [weak self] in
            self?.registerHotkeys()
        }
    }

    func openCommandPalette() {
        let capturedEditingSession = try? container.coordinator.captureCurrentEditingSession()
        commandPaletteController.present(actions: commandPaletteActions) { [weak self] action in
            self?.runAction(action, using: capturedEditingSession)
        }
    }

    func runQuickFix() {
        runAction(.fix)
    }

    func runQuickParaphrase() {
        runAction(.paraphrase)
    }

    func runQuickProfessional() {
        runAction(.professional)
    }

    func undoLastApply() {
        Task { await self.container.coordinator.undoLastAutofix() }
    }

    func terminateApp() {
        NSApp.terminate(nil)
    }

    private func registerHotkeys() {
        let settings = container.userSettings
        let bindings = HotkeyParser.parseBindings(
            palette: settings.paletteHotkey,
            fix: settings.fixHotkey,
            paraphrase: settings.paraphraseHotkey,
            professional: settings.professionalHotkey
        )
        hotkeyManager.register(bindings: bindings) { [weak self] action in
            guard let self else { return }
            switch action {
            case .palette:
                self.openCommandPalette()
            case .fix:
                self.runQuickFix()
            case .paraphrase:
                self.runQuickParaphrase()
            case .professional:
                self.runQuickProfessional()
            }
        }
    }

    private func runAction(_ action: SelectionAction, using capturedEditingSession: TextEditingSession? = nil) {
        let editingSession = capturedEditingSession ?? (try? container.coordinator.captureCurrentEditingSession())
        commandPaletteController.dismiss()
        Task { await container.coordinator.runAction(action, using: editingSession) }
    }
}
