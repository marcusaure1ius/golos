import AppKit
import SwiftUI

@MainActor
final class HotkeyCaptureModel: ObservableObject {
    @Published var captured: Int? = nil
    @Published var isCapturing: Bool = false

    private var monitor: Any?

    func start() {
        guard !isCapturing else { return }
        isCapturing = true
        captured = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            let keycode = Int(event.keyCode)
            Task { @MainActor in
                self.captured = keycode
                self.stop()
            }
            return nil
        }
    }

    func stop() {
        isCapturing = false
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    func displayName(for keycode: Int) -> String {
        switch keycode {
        case 0x3D: return "⌥ Right"
        case 0x3A: return "⌥ Left"
        case 0x38: return "⇧ Left"
        case 0x3C: return "⇧ Right"
        case 0x3B: return "⌃ Left"
        case 0x3E: return "⌃ Right"
        case 0x37: return "⌘ Left"
        case 0x36: return "⌘ Right"
        default:
            if let str = NSEvent.charactersIgnoringModifiers(keyCode: UInt16(keycode), modifiers: []) {
                return str.uppercased()
            }
            return "Key \(String(format: "0x%02X", keycode))"
        }
    }
}

private extension NSEvent {
    static func charactersIgnoringModifiers(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            return nil
        }
        var length = 0
        cgEvent.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else { return nil }
        var chars = [UniChar](repeating: 0, count: length)
        cgEvent.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
        return String(chars.map { Character(UnicodeScalar($0)!) })
    }
}

struct HotkeysPane: View {
    @ObservedObject var settings: AppSettings = .shared
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var capture = HotkeyCaptureModel()
    @Environment(\.palette) var p

    private var currentKeyLabel: String {
        capture.displayName(for: settings.hotkeyKeycode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Заголовок панели
                Text("Хоткеи")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)
                    .padding(.bottom, 28)

                // Секция: Горячая клавиша
                GSectionHeader("Горячая клавиша",
                               desc: "Клавиша, которой запускается диктовка")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Удерживать для записи",
                                desc: "Push-to-talk: говори, пока клавиша зажата",
                                showTopDivider: false) {
                        HStack(spacing: 8) {
                            GKbd(capture.isCapturing ? "Нажмите клавишу…" : currentKeyLabel)
                            Button(capture.isCapturing ? "Отмена" : "Изменить…") {
                                if capture.isCapturing {
                                    capture.stop()
                                } else {
                                    capture.start()
                                }
                            }
                            .buttonStyle(GhostButton())
                        }
                    }
                    // Обе строки редактируют один и тот же hotkeyKeycode —
                    // детектор сам выводит из него PTT и toggle-режим.
                    // Пока идёт захват, оба GKbd показывают «Нажмите клавишу…».
                    GSettingRow("Двойное нажатие — старт/стоп",
                                desc: "Режим без удержания") {
                        HStack(spacing: 8) {
                            GKbd(capture.isCapturing ? "Нажмите клавишу…" : "\(currentKeyLabel) ×2")
                            Button(capture.isCapturing ? "Отмена" : "Изменить…") {
                                if capture.isCapturing {
                                    capture.stop()
                                } else {
                                    capture.start()
                                }
                            }
                            .buttonStyle(GhostButton())
                        }
                    }
                }
                .padding(.bottom, 24)

                // Секция: Тайминги
                GSectionHeader("Тайминги")
                    .padding(.bottom, 10)

                GCard {
                    GSettingRow("Минимальное время удержания",
                                showTopDivider: false) {
                        Menu {
                            Button("150 мс") { settings.holdMs = 150 }
                            Button("200 мс") { settings.holdMs = 200 }
                            Button("300 мс") { settings.holdMs = 300 }
                        } label: {
                            GSelectLabel("\(settings.holdMs) мс")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                    GSettingRow("Окно двойного нажатия") {
                        Menu {
                            Button("200 мс") { settings.doubleTapMs = 200 }
                            Button("300 мс") { settings.doubleTapMs = 300 }
                            Button("500 мс") { settings.doubleTapMs = 500 }
                        } label: {
                            GSelectLabel("\(settings.doubleTapMs) мс")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onChange(of: capture.captured) { newKeycode in
            guard let keycode = newKeycode else { return }
            settings.hotkeyKeycode = keycode
            coordinator.hotkeys?.updateBinding(keycode: Int64(keycode))
        }
    }
}
