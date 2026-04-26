import AppKit
import CoreGraphics
import Foundation

enum HotkeyEvent: Equatable {
    case pttPressed
    case pttReleased
    case toggleTriggered
}

/// Чистая логика распознавания паттернов на правом ⌥.
/// `tick(timeMs:)` вызывается из main loop / периодического таймера, чтобы
/// детектор мог триггерить hold-событие, когда клавиша держится > threshold.
struct HotkeyPatternDetector {
    let holdThresholdMs: Int
    let doubleTapWindowMs: Int
    var emit: (HotkeyEvent) -> Void

    private var keyDownAt: Int? = nil
    private var holdEmitted: Bool = false
    private var lastTapEndAt: Int? = nil

    init(holdThresholdMs: Int, doubleTapWindowMs: Int, emit: @escaping (HotkeyEvent) -> Void) {
        self.holdThresholdMs = holdThresholdMs
        self.doubleTapWindowMs = doubleTapWindowMs
        self.emit = emit
    }

    mutating func onKeyDown(timeMs: Int) {
        keyDownAt = timeMs
        holdEmitted = false
        // Если был недавно tap — это потенциальный double-tap.
        if let lastEnd = lastTapEndAt, timeMs - lastEnd <= doubleTapWindowMs {
            // Подтверждение — на onKeyUp; сейчас просто запоминаем что keyDown произошёл.
        }
    }

    mutating func onKeyUp(timeMs: Int) {
        guard let down = keyDownAt else { return }
        let duration = timeMs - down

        if holdEmitted {
            emit(.pttReleased)
            holdEmitted = false
            lastTapEndAt = nil
        } else if duration < holdThresholdMs {
            // Короткий tap — может быть второй из double-tap.
            if let lastEnd = lastTapEndAt, down - lastEnd <= doubleTapWindowMs {
                emit(.toggleTriggered)
                lastTapEndAt = nil
            } else {
                lastTapEndAt = timeMs
            }
        } else {
            // Долгое нажатие, но hold ещё не emit'нулся — это значит tick не успел.
            // Эмулируем PTT-сессию.
            emit(.pttPressed)
            emit(.pttReleased)
            lastTapEndAt = nil
        }
        keyDownAt = nil
    }

    mutating func tick(timeMs: Int) {
        guard let down = keyDownAt, !holdEmitted else { return }
        if timeMs - down >= holdThresholdMs {
            holdEmitted = true
            emit(.pttPressed)
        }
    }
}

/// Менеджер глобальных хоткеев на основе CGEventTap.
/// Слушает Right Option (kVK_RightOption = 0x3D) по умолчанию, не трогает левый.
@MainActor
final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var detector: HotkeyPatternDetector
    private let onEvent: (HotkeyEvent) -> Void
    private(set) var boundKeycode: Int64

    init(holdThresholdMs: Int = 200, doubleTapWindowMs: Int = 300,
         boundKeycode: Int64 = 0x3D,
         onEvent: @escaping (HotkeyEvent) -> Void) {
        self.boundKeycode = boundKeycode
        self.onEvent = onEvent
        self.detector = HotkeyPatternDetector(
            holdThresholdMs: holdThresholdMs,
            doubleTapWindowMs: doubleTapWindowMs,
            emit: { _ in }
        )
        self.detector.emit = { [weak self] e in
            DispatchQueue.main.async { self?.onEvent(e) }
        }
    }

    func updateBinding(keycode: Int64) {
        self.boundKeycode = keycode
    }

    deinit {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
    }

    /// Запуск перехвата. Требует Input Monitoring permission.
    func start() throws {
        Log.hotkeys.info("perms — mic: \(String(describing: Permissions.microphoneStatus().rawValue), privacy: .public), ax: \(Permissions.accessibilityGranted(), privacy: .public), input: \(Permissions.inputMonitoringGranted(), privacy: .public)")
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: info
        ) else {
            throw NSError(domain: "HotkeyManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "CGEvent.tapCreate failed"])
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.runLoopSource = src

        // Тикер каждые 30ms — чтобы hold ловился вовремя.
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.detector.tick(timeMs: Self.nowMs())
            }
        }
        Log.hotkeys.info("HotkeyManager started")
    }

    fileprivate func handleFlagsChanged(rawKeycode: Int64, isDown: Bool) {
        Log.hotkeys.info("flagsChanged keycode=\(rawKeycode, privacy: .public) isDown=\(isDown, privacy: .public)")
        guard rawKeycode == boundKeycode else { return }
        let now = Self.nowMs()
        if isDown {
            Log.hotkeys.info("right-option DOWN at \(now, privacy: .public)")
            detector.onKeyDown(timeMs: now)
        } else {
            Log.hotkeys.info("right-option UP at \(now, privacy: .public)")
            detector.onKeyUp(timeMs: now)
        }
    }

    static func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    /// Maps a modifier keycode to its corresponding CGEventFlags mask.
    static func modifierFlag(forKeycode kc: Int64) -> CGEventFlags? {
        switch kc {
        case 0x3D, 0x3A: return .maskAlternate
        case 0x3C, 0x38: return .maskShift
        case 0x3E, 0x3B: return .maskControl
        case 0x36, 0x37: return .maskCommand
        default: return nil
        }
    }
}

// CGEventTap callback — C function, можем хранить self через userInfo.
private let hotkeyCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    // Для flagsChanged: модификатор «нажат», если соответствующий flag установлен.
    // Захватываем flags до dispatch, так как CGEventFlags — value type.
    let flags = event.flags
    DispatchQueue.main.async {
        let flagForBound = HotkeyManager.modifierFlag(forKeycode: manager.boundKeycode) ?? .maskAlternate
        let isDown = flags.contains(flagForBound)
        manager.handleFlagsChanged(rawKeycode: keycode, isDown: isDown)
    }
    return Unmanaged.passUnretained(event)
}
