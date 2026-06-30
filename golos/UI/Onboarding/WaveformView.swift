import SwiftUI

enum Waveform {
    /// Высоты столбиков из массива уровней. Берёт последние `count`
    /// значений, недостающие слева добивает нулями. Масштаб: 0 → minHeight,
    /// 1.0 → maxHeight + minHeight. Отрицательные и сверхгромкие клампятся
    /// в [minHeight, maxHeight + minHeight].
    static func barHeights(levels: [Float], count: Int, maxHeight: CGFloat, minHeight: CGFloat = 3) -> [CGFloat] {
        guard count > 0 else { return [] }
        var src = Array(levels.suffix(count))
        if src.count < count {
            src = Array(repeating: Float(0), count: count - src.count) + src
        }
        let total = maxHeight + minHeight
        return src.map { v in
            max(minHeight, min(total, CGFloat(v) * total))
        }
    }
}

struct WaveformView: View {
    var levels: [Float]
    var live: Bool
    var barCount: Int = 7
    var maxHeight: CGFloat = 90

    private let idleColor = Color(hex: 0xc7c7cc)
    private var liveGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xff8a7d), Color(hex: 0xff3b30)],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let heights = Waveform.barHeights(levels: levels, count: barCount, maxHeight: maxHeight)
        HStack(spacing: 5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                Capsule()
                    .fill(live ? AnyShapeStyle(liveGradient) : AnyShapeStyle(idleColor))
                    .frame(width: 6, height: max(3, h))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.12), value: heights)
    }
}
