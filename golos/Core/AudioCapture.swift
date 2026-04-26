import AVFoundation
import Combine

/// Захватывает звук с дефолтного (или выбранного) микрофона, конвертирует в
/// 16kHz mono Int16 PCM, отдаёт сэмплы через `samples` и публикует RMS через `level`.
@MainActor
final class AudioCapture: ObservableObject {
    private let engine = AVAudioEngine()
    private nonisolated(unsafe) var converter: AVAudioConverter?
    private nonisolated(unsafe) let targetFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    /// Stream с сырыми Int16 LE сэмплами (Data). **Живёт всё время существования
    /// AudioCapture** — НЕ пересоздаётся при start/stop. Consumer subscribe'ится
    /// один раз и получает данные на протяжении всех recording-сессий.
    let samples: AsyncStream<Data>
    private let samplesContinuation: AsyncStream<Data>.Continuation

    /// Stream с уровнем (RMS, [0...1]).
    @Published private(set) var level: Float = 0

    private var isRunning = false

    init() {
        var cont: AsyncStream<Data>.Continuation!
        self.samples = AsyncStream { c in cont = c }
        self.samplesContinuation = cont
    }

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(
                domain: "AudioCapture", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "cannot create converter"]
            )
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buf, _ in
            guard let self else { return }
            self.process(inputBuffer: buf)
        }

        try engine.start()
        isRunning = true
        Log.audio.info("AudioCapture started; inputFmt=\(String(describing: inputFormat), privacy: .public)")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // НЕ закрываем samplesContinuation — он живёт всё время. Просто отключаем
        // источник данных. На следующий start() поток заработает снова.
        converter = nil
        isRunning = false
        level = 0
        Log.audio.info("AudioCapture stopped")
    }

    // MARK: Private

    nonisolated private func process(inputBuffer: AVAudioPCMBuffer) {
        // Конвертация в 16kHz mono Int16.
        guard let outBuf = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(inputBuffer.frameLength)
                * targetFormat.sampleRate / inputBuffer.format.sampleRate) + 32
        ) else { return }

        var error: NSError?
        var consumed = false
        let status = converter?.convert(to: outBuf, error: &error, withInputFrom: { _, outStatus in
            if consumed { outStatus.pointee = .endOfStream; return nil }
            outStatus.pointee = .haveData
            consumed = true
            return inputBuffer
        })
        if status != .haveData {
            return
        }

        // Достаём байты.
        let frameCount = Int(outBuf.frameLength)
        guard frameCount > 0,
              let int16Ptr = outBuf.int16ChannelData?[0] else { return }
        let byteCount = frameCount * 2
        let data = Data(bytes: int16Ptr, count: byteCount)

        // RMS.
        var sumSquares: Double = 0
        for i in 0..<frameCount {
            let s = Double(int16Ptr[i]) / Double(Int16.max)
            sumSquares += s * s
        }
        let rms = Float(sqrt(sumSquares / Double(frameCount)))

        // Публикация — на main actor. samplesContinuation живёт всё время существования.
        Task { @MainActor [weak self] in
            self?.samplesContinuation.yield(data)
            self?.level = rms
        }
    }
}
