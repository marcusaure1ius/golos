import AVFoundation
import AppKit
import IOKit
import IOKit.hid

/// Утилиты для проверки и запроса системных разрешений macOS.
enum Permissions {
    // MARK: Microphone

    static func microphoneStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Просит у системы доступ к микрофону. Колбэк на main queue.
    static func requestMicrophone(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { done(granted) }
        }
    }

    // MARK: Accessibility

    /// Проверка без prompt.
    static func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Проверка с promot — открывает System Settings → Accessibility.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Прямая ссылка на System Settings → Privacy → Accessibility.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Input Monitoring

    /// Возвращает текущий статус (.granted / .denied / .unknown).
    static func inputMonitoringStatus() -> IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    static func inputMonitoringGranted() -> Bool {
        inputMonitoringStatus() == kIOHIDAccessTypeGranted
    }

    /// Запросить доступ — обычно открывает System Settings.
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Notifications

    static func openNotificationsSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        NSWorkspace.shared.open(url)
    }
}
