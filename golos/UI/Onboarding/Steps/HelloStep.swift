import SwiftUI

struct HelloStep: View {
    var body: some View {
        StepLayout(
            icon: "waveform",
            title: "Привет! Это Golos",
            subtitle: "Диктуй текст в любое приложение macOS. Распознавание локальное — голос и текст никуда не уходят. Зажми правый ⌥, говори — текст появится там, где курсор."
        ) {
            EmptyView()
        }
    }
}
