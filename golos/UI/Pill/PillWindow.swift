import AppKit
import SwiftUI

/// NSPanel поверх всех окон, не крадёт фокус.
@MainActor
final class PillWindow {
    private var window: NSPanel?
    let viewModel: PillViewModel

    init() {
        viewModel = PillViewModel(state: .recording(mode: .ptt))
    }

    func show() {
        if window == nil { window = makeWindow() }
        position(window!)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSPanel {
        let host = NSHostingController(rootView: PillView(vm: viewModel))
        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.isFloatingPanel = true
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.contentViewController = host
        w.ignoresMouseEvents = true
        return w
    }

    private func position(_ w: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = w.frame.size
        let x = frame.origin.x + (frame.size.width - size.width) / 2
        let y = frame.origin.y + 60 // 60px от низа
        w.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
