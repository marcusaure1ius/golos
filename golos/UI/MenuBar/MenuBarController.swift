import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    enum IconState { case idle, recording, processing, error }

    private var statusItem: NSStatusItem?
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: 22)
        item.button?.image = renderIcon(state: .idle)
        item.button?.image?.isTemplate = true
        item.menu = makeMenu()
        statusItem = item
    }

    func setState(_ state: IconState) {
        guard let btn = statusItem?.button else { return }
        btn.image = renderIcon(state: state)
        btn.image?.isTemplate = (state == .idle)
        btn.contentTintColor = {
            switch state {
            case .idle:       return nil
            case .recording:  return NSColor.systemRed
            case .processing: return NSColor.tertiaryLabelColor
            case .error:      return NSColor.systemOrange
            }
        }()
    }

    private func renderIcon(state: IconState) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        let bars: [(CGFloat, CGFloat)] = [
            (2, 4), (7, 10), (12, 16), (17, 8), (22, 2)
        ]
        let color = NSColor.white
        color.set()
        for (x, h) in bars {
            let y = (22 - h) / 2
            let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 3, height: h), xRadius: 1.5, yRadius: 1.5)
            path.fill()
        }
        image.unlockFocus()
        return image
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Открыть настройки", action: #selector(MenuBarTarget.openSettings(_:)), keyEquivalent: ",")
        openItem.target = target
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Выйти из Golos", action: #selector(MenuBarTarget.quit(_:)), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
        return menu
    }

    private lazy var target = MenuBarTarget(open: onOpenSettings, quit: onQuit)
}

/// NSObject target — нужен потому, что @MainActor класс не может быть корректным
/// `target:` для NSMenuItem без переходных мостов в Swift 6 strict concurrency.
final class MenuBarTarget: NSObject {
    private let open: () -> Void
    private let quit: () -> Void
    init(open: @escaping () -> Void, quit: @escaping () -> Void) {
        self.open = open; self.quit = quit
    }
    @objc func openSettings(_ sender: Any?) { open() }
    @objc func quit(_ sender: Any?) { quit() }
}
