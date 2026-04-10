import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class CommandPaletteController: NSObject {
    private var panel: CommandPalettePanel?
    private var session: ActionPaletteSession?
    private var chooseHandler: ((SelectionAction) -> Void)?
    private let panelSize = NSSize(width: 360, height: 292)

    func present(
        actions: [SelectionAction],
        initialAction: SelectionAction = .fix,
        onChoose: @escaping (SelectionAction) -> Void
    ) {
        let panel = self.panel ?? buildPanel()
        let session = ActionPaletteSession(actions: actions, initialAction: initialAction)

        self.session = session
        chooseHandler = onChoose

        panel.keyDownHandler = { [weak self] event in
            self?.handleKeyDown(event)
        }
        panel.contentView = NSHostingView(
            rootView: CommandPaletteView(
                session: session,
                onChoose: { [weak self] action in
                    self?.choose(action)
                },
                onHighlight: { [weak self] action in
                    self?.session?.highlight(action)
                },
                onCancel: { [weak self] in
                    self?.dismiss()
                }
            )
        )

        positionNearMouse(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        session = nil
        chooseHandler = nil
    }

    private func choose(_ action: SelectionAction) {
        let handler = chooseHandler
        dismiss()
        handler?(action)
    }

    private func buildPanel() -> CommandPalettePanel {
        let panel = CommandPalettePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard let session else { return }

        switch Int(event.keyCode) {
        case Int(kVK_DownArrow):
            session.moveSelection(by: 1)
        case Int(kVK_UpArrow):
            session.moveSelection(by: -1)
        case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
            choose(session.highlightedAction)
        case Int(kVK_Escape):
            dismiss()
        default:
            break
        }
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else {
            panel.setFrameOrigin(NSPoint(x: mouse.x - panelSize.width / 2, y: mouse.y - panelSize.height - 18))
            return
        }

        let visible = screen.visibleFrame
        let targetX = mouse.x - panel.frame.width / 2
        let targetY = mouse.y - panel.frame.height - 18

        let clampedX = min(max(targetX, visible.minX + 12), visible.maxX - panel.frame.width - 12)
        let clampedY = min(max(targetY, visible.minY + 12), visible.maxY - panel.frame.height - 12)

        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}

private final class CommandPalettePanel: NSPanel {
    var keyDownHandler: ((NSEvent) -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        keyDownHandler?(event)
    }
}
