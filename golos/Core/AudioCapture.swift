import AVFoundation
import CoreAudio
import Combine

/// Захватывает звук с дефолтного (или выбранного) микрофона, конвертирует в
/// 16kHz mono Int16 PCM, отдаёт сэмплы через `samples` и публикует RMS через `level`.
@MainActor
final class AudioCapture: ObservableObject {
    private let engine = AVAudioEngine()
    private static let targetFormat: AVAudioFormat = AVAudioFormat(
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
    private var preferredDeviceUid: String?
    private var voiceProcessingEnabled: Bool = false

    init() {
        var cont: AsyncStream<Data>.Continuation!
        self.samples = AsyncStream { c in cont = c }
        self.samplesContinuation = cont
    }

    /// Stores the preferred device UID and voice processing flag.
    /// If currently running, stops and restarts to apply new settings.
    func applySettings(deviceUid: String, voiceProcessingEnabled: Bool) {
        self.preferredDeviceUid = deviceUid.isEmpty ? nil : deviceUid
        self.voiceProcessingEnabled = voiceProcessingEnabled
        if isRunning {
            stop()
            do {
                try start()
            } catch {
                Log.audio.error("AudioCapture restart failed after applySettings: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Прогрев Voice Processing AU чтобы первый `start()` не блокировал MainActor
    /// на 2-3 секунды. `setVoiceProcessingEnabled(true)` инициализирует AUVoiceProcessing
    /// внутри AVAudioEngine — этот init однократный, но первый вызов очень медленный.
    /// Вызывается из AppCoordinator после warmup модели (когда permission уже есть).
    func prewarm() {
        do {
            try engine.inputNode.setVoiceProcessingEnabled(voiceProcessingEnabled)
            Log.audio.info("AudioCapture prewarm done (voiceProcessing=\(self.voiceProcessingEnabled, privacy: .public))")
        } catch {
            Log.audio.warning("AudioCapture prewarm failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func start() throws {
        guard !isRunning else { return }

        // Apply preferred device if set
        if let uid = preferredDeviceUid,
           let deviceID = AudioDevices.audioDeviceID(forUid: uid) {
            var mutableDeviceID = deviceID
            let err = AudioUnitSetProperty(
                engine.inputNode.audioUnit!,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if err != noErr {
                Log.audio.warning("Failed to set preferred audio device (uid=\(uid, privacy: .public)): \(err, privacy: .public)")
            }
        }

        // Apply voice processing
        do {
            try engine.inputNode.setVoiceProcessingEnabled(voiceProcessingEnabled)
        } catch {
            Log.audio.warning("setVoiceProcessingEnabled failed: \(error.localizedDescription, privacy: .public)")
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat) else {
            throw NSError(domain: "AudioCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "cannot create converter"])
        }
        let targetFormat = Self.targetFormat
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buf, _ in
            guard let self else { return }
            self.process(inputBuffer: buf, converter: converter, targetFormat: targetFormat)
        }

        try engine.start()
        isRunning = true
        Log.audio.info("AudioCapture started; inputFmt=\(String(describing: inputFormat), privacy: .public)")
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        level = 0
        Log.audio.info("AudioCapture stopped")
    }

    // MARK: Private

    nonisolated private func process(
        inputBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        guard let outBuf = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(inputBuffer.frameLength)
                * targetFormat.sampleRate / inputBuffer.format.sampleRate) + 32
        ) else { return }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outBuf, error: &error, withInputFrom: { _, outStatus in
            if consumed {
                // КРИТИЧНО: .noDataNow, НЕ .endOfStream. Конвертер живёт между tap-buffer'ами,
                // и .endOfStream после первого input блокирует все последующие convert() calls
                // (он считает что поток окончен). С .noDataNow конвертер просто завершает текущий
                // вызов и готов принять следующий buffer на следующем tap'е.
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            consumed = true
            return inputBuffer
        })
        if status != .haveData { return }

        let frameCount = Int(outBuf.frameLength)
        guard frameCount > 0, let int16Ptr = outBuf.int16ChannelData?[0] else { return }
        let byteCount = frameCount * 2
        let data = Data(bytes: int16Ptr, count: byteCount)

        var sumSquares: Double = 0
        for i in 0..<frameCount {
            let s = Double(int16Ptr[i]) / Double(Int16.max)
            sumSquares += s * s
        }
        let rms = Float(sqrt(sumSquares / Double(frameCount)))

        Task { @MainActor [weak self] in
            self?.samplesContinuation.yield(data)
            self?.level = rms
        }
    }
}
