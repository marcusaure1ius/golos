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

    private var currentKeyLabel: String {
        capture.displayName(for: settings.hotkeyKeycode)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Push-to-talk:") {
                    HStack {
                        Text(capture.isCapturing ? "Нажмите клавишу…" : "\(currentKeyLabel) · hold")
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        Button(capture.isCapturing ? "Отмена" : "Изменить…") {
                            if capture.isCapturing {
                                capture.stop()
                            } else {
                                capture.start()
                            }
                        }
                    }
                }
                .onChange(of: capture.captured) { newKeycode in
                    guard let keycode = newKeycode else { return }
                    settings.hotkeyKeycode = keycode
                    coordinator.hotkeys?.updateBinding(keycode: Int64(keycode))
                }

                LabeledContent("Toggle:") {
                    HStack {
                        Text("\(currentKeyLabel) · ×2")
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }

                Picker("Минимальное время удержания:", selection: $settings.holdMs) {
                    Text("150 мс").tag(150)
                    Text("200 мс").tag(200)
                    Text("300 мс").tag(300)
                }
                Picker("Окно double-tap:", selection: $settings.doubleTapMs) {
                    Text("200 мс").tag(200)
                    Text("300 мс").tag(300)
                    Text("500 мс").tag(500)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Хоткеи")
    }
}
