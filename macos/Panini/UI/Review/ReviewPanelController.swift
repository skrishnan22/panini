import AppKit
import SwiftUI

@MainActor
final class ReviewPanelController: NSObject, ReviewPresenting {
    var applyHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?
    var retryHandler: (() -> Void)?

    private var panel: NSPanel?
    private let panelSize = NSSize(width: 472, height: 332)

    func present(session: ReviewSession) {
        let panel = self.panel ?? buildPanel()
        let rootView = ReviewPanelView(
            session: session,
            onApply: { [weak self] in self?.applyHandler?() },
            onCancel: { [weak self] in
                if let cancelHandler = self?.cancelHandler {
                    cancelHandler()
                } else {
                    self?.dismiss()
                }
            },
            onRetry: { [weak self] in self?.retryHandler?() }
        )

        panel.contentView = NSHostingView(rootView: rootView)
        positionNearMouse(panel)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    func makePanelForTesting() -> NSPanel {
        buildPanel()
    }

    private func buildPanel() -> NSPanel {
        let panel = NSPanel(
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
