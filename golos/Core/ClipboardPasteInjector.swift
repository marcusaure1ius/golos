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

        // 1. Try AX direct text insertion — no clipboard needed.
        if tryAXInsertion(text: text) {
            Log.injection.info("AX insertion succeeded")
            return .injected
        }

        // 2. Fallback: clipboard paste via Cmd+V.
        let isText = isFocusedElementTextual()
        let pb = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(pb)
        let initialCount = pb.changeCount

        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        // Конвенция Apple: org.nspasteboard.ConcealedType — clipboard managers это уважают.
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.writeObjects([item])

        if isText {
            postCmdV()
            // Wait for the front app to read the pasteboard before we restore it.
            await Self.waitForPasteAcknowledgement(timeout: 0.25)
            snapshot.restore(to: pb)
            Log.injection.info("paste injected")
            return .injected
        } else {
            Log.injection.info("focus is not textual — left in clipboard")
            // Не восстанавливаем — пользователь увидит наш текст, как просил.
            _ = initialCount  // suppress unused warning
            return .copiedToClipboard
        }
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

    @MainActor
    private func isFocusedElementTextual() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused
        )
        guard status == .success, let element = focused else { return false }

        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXRoleAttribute as CFString, &roleValue
        )
        guard let role = roleValue as? String else { return false }
        let textualRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXWebArea",
            "AXComboBox",
            "AXSearchField",
        ]
        return textualRoles.contains(role)
    }

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
