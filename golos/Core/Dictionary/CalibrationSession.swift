import Foundation

/// Управляет проходом калибровки: показывает фразы, записывает их через координатор
/// (в режиме «перехвата», без вставки), собирает пары «эталон ↔ распознанное»,
/// считает результат и применяет его в словарь.
@MainActor
final class CalibrationSession: ObservableObject {

    enum Phase: Equatable {
        case intro
        case recording
        case results
    }

    @Published private(set) var phase: Phase = .intro
    @Published private(set) var index: Int = 0
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var result: CalibrationResult?

    let phrases: [String]
    private var pairs: [CalibrationPair] = []
    private weak var coordinator: DictationCoordinator?

    init(phrases: [String] = Array(CalibrationPhrases.all.prefix(12))) {
        self.phrases = phrases
    }

    var currentPhrase: String { phrases.indices.contains(index) ? phrases[index] : "" }
    var progress: (done: Int, total: Int) { (index, phrases.count) }
    /// Достаточно ли собрано, чтобы завершить досрочно.
    var canFinishEarly: Bool { pairs.count >= 3 }

    // MARK: - Жизненный цикл

    func begin(coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        pairs.removeAll()
        index = 0
        result = nil
        isRecording = false
        // Перехватываем распознанный текст вместо вставки.
        coordinator.transcriptCapture = { [weak self] text in
            self?.captured(text)
        }
        phase = .recording
    }

    /// Старт/стоп записи текущей фразы (программный toggle координатора).
    func toggleRecord() {
        guard phase == .recording, let coordinator else { return }
        coordinator.handle(.toggleTriggered)
        isRecording.toggle()
    }

    /// Прервать калибровку без применения.
    func cancel() {
        coordinator?.transcriptCapture = nil
        coordinator = nil
        isRecording = false
        phase = .intro
    }

    /// Досрочно завершить и посчитать результат по собранному.
    func finishEarly() {
        finalizeResult()
    }

    // MARK: - Приём распознанного

    private func captured(_ text: String) {
        isRecording = false
        pairs.append(CalibrationPair(expected: currentPhrase, heard: text))
        if index + 1 < phrases.count {
            index += 1
        } else {
            finalizeResult()
        }
    }

    private func finalizeResult() {
        coordinator?.transcriptCapture = nil
        result = CalibrationAnalyzer.analyze(pairs)
        phase = .results
    }

    // MARK: - Применение

    /// Записать найденное в словарь: bias-термины (только распознавание) и правила
    /// замены (распознавание + правка текста).
    func apply() async {
        guard let result else { return }
        for term in result.biasTerms {
            await DictionaryStore.shared.add(pattern: "", replacement: term)
        }
        for s in result.suggestions {
            await DictionaryStore.shared.add(pattern: s.pattern, replacement: s.replacement)
        }
    }
}
