import SwiftUI

struct MenuBarView: View {
    let onOpenPalette: () -> Void
    let onQuickFix: () -> Void
    let onQuickParaphrase: () -> Void
    let onQuickProfessional: () -> Void
    let onUndoLastApply: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        Group {
            Button("Open Command Palette", action: onOpenPalette)
            Button("Quick Fix Grammar", action: onQuickFix)
            Button("Quick Paraphrase", action: onQuickParaphrase)
            Button("Quick Professional", action: onQuickProfessional)
            Button("Undo Last Apply", action: onUndoLastApply)
            Divider()
            Button("Open Settings…", action: onOpenSettings)
            Divider()
            Button("Quit", action: onQuit)
        }
    }
}
