import SwiftUI

struct HelloStep: View {
    var body: some View {
        StepLayout(
            iconColors: [.indigo, .purple],
            icon: "waveform",
            title: "Привет! Это Golos",
            subtitle: "Диктуй текст в любое приложение macOS. Распознавание локальное — голос и текст никуда не уходят. Зажми правый ⌥, говори — текст появится там, где курсор."
        ) {
            WaveformView(levels: [0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7], live: true, barCount: 7, maxHeight: 120)
        } content: {
            EmptyView()
        }
    }
}
