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

        // 1. Решить, есть ли текстовое фокусное поле.
        let isText = isFocusedElementTextual()

        // 2. Сохранить текущий clipboard.
        let pb = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(pb)

        // 3. Положить наш текст с пометкой concealed.
        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        // Конвенция Apple: org.nspasteboard.ConcealedType — clipboard managers это уважают.
        item.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.writeObjects([item])

        if isText {
            // Симулировать Cmd+V.
            postCmdV()
            // Дать системе обработать paste.
            try? await Task.sleep(nanoseconds: 60_000_000)
            snapshot.restore(to: pb)
            Log.injection.info("paste injected")
            return .injected
        } else {
            Log.injection.info("focus is not textual — left in clipboard")
            // Не восстанавливаем — пользователь увидит наш текст, как просил.
            return .copiedToClipboard
        }
    }

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
