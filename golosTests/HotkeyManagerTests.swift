import Testing
import Foundation
@testable import golos

struct HotkeyPatternDetectorTests {
    @Test func holdEmitsHoldEventAfterThreshold() {
        var emitted: [HotkeyEvent] = []
        var d = HotkeyPatternDetector(holdThresholdMs: 200, doubleTapWindowMs: 300) { e in
            emitted.append(e)
        }
        d.onKeyDown(timeMs: 0)
        d.tick(timeMs: 199)
        #expect(emitted == [])
        d.tick(timeMs: 200)
        #expect(emitted == [.pttPressed])
        d.onKeyUp(timeMs: 500)
        #expect(emitted == [.pttPressed, .pttReleased])
    }

    @Test func quickTapDoesNotEmit() {
        var emitted: [HotkeyEvent] = []
        var d = HotkeyPatternDetector(holdThresholdMs: 200, doubleTapWindowMs: 300) { e in
            emitted.append(e)
        }
        d.onKeyDown(timeMs: 0)
        d.onKeyUp(timeMs: 50)
        #expect(emitted == [])
    }

    @Test func doubleTapEmitsToggle() {
        var emitted: [HotkeyEvent] = []
        var d = HotkeyPatternDetector(holdThresholdMs: 200, doubleTapWindowMs: 300) { e in
            emitted.append(e)
        }
        d.onKeyDown(timeMs: 0)
        d.onKeyUp(timeMs: 50)
        d.onKeyDown(timeMs: 200)
        d.onKeyUp(timeMs: 240)
        #expect(emitted == [.toggleTriggered])
    }

    @Test func tapsTooFarApartDoNotTrigger() {
        var emitted: [HotkeyEvent] = []
        var d = HotkeyPatternDetector(holdThresholdMs: 200, doubleTapWindowMs: 300) { e in
            emitted.append(e)
        }
        d.onKeyDown(timeMs: 0)
        d.onKeyUp(timeMs: 50)
        d.onKeyDown(timeMs: 500) // 450ms gap > 300ms window
        d.onKeyUp(timeMs: 540)
        #expect(emitted == [])
    }
}
