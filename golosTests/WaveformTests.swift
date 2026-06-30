import Testing
import CoreGraphics
@testable import golos

@Suite struct WaveformTests {
    @Test func padsFrontWhenFewerLevels() {
        let h = Waveform.barHeights(levels: [1.0], count: 3, maxHeight: 100, minHeight: 0)
        #expect(h == [0, 0, 100])
    }

    @Test func clampsAndScales() {
        let h = Waveform.barHeights(levels: [-1, 0.5, 2.0], count: 3, maxHeight: 100, minHeight: 10)
        #expect(h == [10, 55, 100])
    }
}
