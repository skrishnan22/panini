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

        Task {
            AppLogger.server.info(
                "App launch config host=\(self.container.config.serverHost, privacy: .public) port=\(self.container.config.serverPort) python=\(self.container.config.pythonExecutablePath, privacy: .public) cwd=\(self.container.config.serverEntryWorkingDirectory.path, privacy: .public)"
            )

            if !(await self.container.serverHealthClient.isHealthy()) {
                try? self.container.serverProcessManager.startIfNeeded()
            }
            await self.container.settingsViewModel.refreshServerHealth()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.serverProcessManager.stop()
    }

    func openCommandPalette() {
        commandPaletteController.present(actions: commandPaletteActions) { [weak self] action in
            self?.runAction(action)
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

    func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func runAction(_ action: SelectionAction) {
        commandPaletteController.dismiss()
        Task { await container.coordinator.runAction(action) }
    }
}
