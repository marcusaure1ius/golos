import AppKit
import ApplicationServices

/// Snapshot текущего состояния clipboard (все типы, не только строка).
struct ClipboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(_ pb: NSPasteboard) -> ClipboardSnapshot {
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        guard let pbItems = pb.pasteboardItems else { return ClipboardSnapshot(items: []) }
        for item in pbItems {
            var typed: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typed[type] = data
                }
            }
            items.append(typed)
        }
        return ClipboardSnapshot(items: items)
    }

    func restore(to pb: NSPasteboard) {
        pb.clearContents()
        var newItems: [NSPasteboardItem] = []
        for typed in items {
            let item = NSPasteboardItem()
            for (type, data) in typed {
                item.setData(data, forType: type)
            }
            newItems.append(item)
        }
        pb.writeObjects(newItems)
    }
}

final class ClipboardPasteInjector: TextInjector {
    @MainActor
    func inject(text: String) async -> InjectionOutcome {
        guard !text.isEmpty else { return .injected }

        // 1. Try AX direct text insertion — без clipboard, идеально для нативных
        //    NSTextField/NSTextView (Chrome address bar, Notes, и т.п.).
        if tryAXInsertion(text: text) {
            Log.injection.info("AX insertion succeeded")
            return .injected
        }

        // 2. Fallback: clipboard paste via Cmd+V. Делаем безусловно — для Electron-based
        //    приложений (VS Code, Slack, Discord, Cursor) AX-чтение фокуса возвращает
        //    nothing/AXGroup, но Cmd+V работает корректно. Если фокус не на text input —
        //    юзер сам прервёт; clipboard-only fallback оставлял текст потерянным даже
        //    в обычных IDE.
        if shouldSkipPaste() {
            // Не вставляем в Finder и подобные апп, где Cmd+V имеет иной смысл.
            Log.injection.info("paste skipped — front app in skip list")
            return .copiedToClipboard
        }

        let pb = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(pb)

        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        // Конвенция Apple: org.nspasteboard.ConcealedType — clipboard managers это уважают.
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.writeObjects([item])

        postCmdV()
        // Wait for the front app to read the pasteboard before we restore it.
        await Self.waitForPasteAcknowledgement(timeout: 0.25)
        snapshot.restore(to: pb)
        Log.injection.info("paste injected via Cmd+V")
        return .injected
    }

    /// Вернуть true если frontmost app — Finder и т.п., где Cmd+V не должен делать paste текста.
    @MainActor
    private func shouldSkipPaste() -> Bool {
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let skip: Set<String> = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.controlcenter",
            "com.apple.Spotlight",
            "com.golos-app.golos",  // мы сами
        ]
        return skip.contains(bundleId)
    }

    // MARK: - AX insertion

    @MainActor
    private func tryAXInsertion(text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success, let element = focused else { return false }

        let axElement = element as! AXUIElement
        let err = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        return err == .success
    }

    // MARK: - Pasteboard polling

    /// Polls `pasteboard.changeCount` until it differs from `initialCount` or `timeout` elapses.
    /// Returns `true` if a change was detected.
    static func waitForPasteboardChange(
        pasteboard: NSPasteboard,
        initialCount: Int,
        timeout: TimeInterval
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != initialCount { return true }
            try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms
        }
        return pasteboard.changeCount != initialCount
    }

    /// Minimum 30ms acknowledgement wait — gives the front app time to read the pasteboard
    /// before we restore it. Does not poll changeCount (we don't know what to watch for).
    static func waitForPasteAcknowledgement(timeout: TimeInterval) async {
        try? await Task.sleep(nanoseconds: 30_000_000)  // 30ms minimum
    }

    // MARK: - Helpers

    private func postCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vCode: CGKeyCode = 0x09 // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vCode, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vCode, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
