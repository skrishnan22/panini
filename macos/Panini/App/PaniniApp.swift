import SwiftUI

@main
struct PaniniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Panini", systemImage: "text.badge.checkmark") {
            MenuBarView(
                onOpenPalette: appDelegate.openCommandPalette,
                onQuickFix: appDelegate.runQuickFix,
                onQuickParaphrase: appDelegate.runQuickParaphrase,
                onQuickProfessional: appDelegate.runQuickProfessional,
                onUndoLastApply: appDelegate.undoLastApply,
                onOpenSettings: appDelegate.openSettingsWindow,
                onQuit: appDelegate.terminateApp
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(viewModel: DIContainer.shared.settingsViewModel)
                .frame(width: 560, height: 480)
        }
    }
}
