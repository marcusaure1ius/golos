import Foundation

/// Реализация TranscriptionProvider, общающаяся с `golos-asr` sidecar
/// через stdin/stdout (JSON-lines) + отдельный pipe для PCM.
final class LocalGigaAMProvider: TranscriptionProvider {
    private let sidecarURL: URL
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?

    /// Pipe для аудио (Swift пишет → sidecar читает). Read-end передаётся sidecar
    /// через --audio-fd, мы (write-end) держим у себя.
    private var writer: AudioWriter?

    /// Параллельный listener stdout — публикует Response в continuation.
    private var responseStream: AsyncStream<SidecarResponse>?
    private var responseContinuation: AsyncStream<SidecarResponse>.Continuation?

    private let partialsContinuation: AsyncStream<String>.Continuation
    let partials: AsyncStream<String>

    private var isShuttingDown = false
    private var samplesEnqueued: UInt64 = 0

    init(sidecarURL: URL = AppPaths.sidecarBinary) {
        self.sidecarURL = sidecarURL
        var cont: AsyncStream<String>.Continuation!
        self.partials = AsyncStream { c in cont = c }
        self.partialsContinuation = cont
    }

    deinit { partialsContinuation.finish() }

    func start(modelDir: URL) async throws {
        try spawnSidecarIfNeeded()
        // Ждём hello.
        guard case .hello = try await nextResponse(timeout: 5) else {
            throw TranscriptionError.protocolError("expected hello")
        }
        // Шлём load.
        try send(.load(modelPath: modelDir.path))
        let resp = try await nextResponse(timeout: 30)
        switch resp {
        case .ready: return
        case .error(_, let msg): throw TranscriptionError.modelLoadFailed(msg)
        default: throw TranscriptionError.protocolError("unexpected after load: \(resp)")
        }
    }

    func beginSession() async throws {
        samplesEnqueued = 0
        try send(.beginSession)
        let resp = try await nextResponse(timeout: 5)
        guard case .sessionStarted = resp else {
            throw TranscriptionError.protocolError("expected session_started, got \(resp)")
        }
    }

    func feed(samples: Data) throws {
        guard let w = writer else { throw TranscriptionError.sidecarNotRunning }
        samplesEnqueued += UInt64(samples.count / 2)  // Int16 → 2 байта на семпл
        Task { await w.enqueue(samples) }
    }

    func flushSamples() async {
        if let w = writer { await w.flush() }
    }

    func finalize() async throws -> Transcript {
        try send(.endSession(samplesTotal: samplesEnqueued))
        // Ждём final / error. Игнорируем partial по дороге (в MVP не используем).
        while true {
            let resp = try await nextResponse(timeout: 30)
            switch resp {
            case .partial: continue
            case .final(let text, let ms):
                return Transcript(text: text, durationMs: ms)
            case .error(_, let msg):
                throw TranscriptionError.transcribeFailed(msg)
            default:
                throw TranscriptionError.protocolError("unexpected during finalize: \(resp)")
            }
        }
    }

    func cancel() async {
        try? send(.cancel)
        // Ждём cancelled, но не валим если timeout.
        _ = try? await nextResponse(timeout: 2)
    }

    func shutdown() async {
        isShuttingDown = true
        try? send(.shutdown)
        // Закрываем audio write end — sidecar получит EOF, audio thread выйдет.
        if let w = writer { await w.close() }
        writer = nil
        // Ждём процесс с timeout.
        let proc = process
        process = nil
        await Task.detached {
            proc?.waitUntilExit()
        }.value
        responseContinuation?.finish()
    }

    // MARK: Private

    private func spawnSidecarIfNeeded() throws {
        if process?.isRunning == true { return }

        // Создаём audio pipe.
        var fds: [Int32] = [0, 0]
        if pipe(&fds) != 0 {
            throw TranscriptionError.sidecarNotRunning
        }
        let readFd = fds[0]   // отдаём sidecar'у
        let writeFd = fds[1]  // оставляем себе

        // Снимаем CLOEXEC c readFd, чтобы Process унаследовал его.
        let flags = fcntl(readFd, F_GETFD)
        _ = fcntl(readFd, F_SETFD, flags & ~FD_CLOEXEC)

        let proc = Process()
        proc.executableURL = sidecarURL
        proc.arguments = ["--audio-fd", String(readFd)]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        try proc.run()
        // Закрываем readFd в родителе — он у sidecar'а.
        close(readFd)

        process = proc
        stdinHandle = stdin.fileHandleForWriting
        stdoutHandle = stdout.fileHandleForReading
        stderrHandle = stderr.fileHandleForReading
        writer = AudioWriter(fd: writeFd)

        // Стрим ответов — отдельная задача.
        var cont: AsyncStream<SidecarResponse>.Continuation!
        responseStream = AsyncStream { c in cont = c }
        responseContinuation = cont
        let outHandle = stdoutHandle!
        let partialsCont = partialsContinuation
        Task.detached { [weak self] in
            await Self.readResponseLoop(handle: outHandle, continuation: cont, partials: partialsCont)
            // Авто-перезапуск, если не shutdown.
            if let self, !self.isShuttingDown {
                Log.sidecar.warning("sidecar closed unexpectedly")
            }
        }
        // Логирование stderr — отдельная задача.
        let errHandle = stderrHandle!
        Task.detached {
            for try await line in errHandle.bytes.lines {
                Log.sidecar.debug("\(line, privacy: .public)")
            }
        }
    }

    private static func readResponseLoop(
        handle: FileHandle,
        continuation: AsyncStream<SidecarResponse>.Continuation,
        partials: AsyncStream<String>.Continuation
    ) async {
        let decoder = JSONDecoder()
        do {
            for try await line in handle.bytes.lines {
                guard let data = line.data(using: .utf8) else { continue }
                do {
                    let resp = try decoder.decode(SidecarResponse.self, from: data)
                    if case .partial(let t) = resp {
                        partials.yield(t)
                    }
                    continuation.yield(resp)
                } catch {
                    Log.sidecar.error("decode error: \(error.localizedDescription, privacy: .public) line=\(line, privacy: .public)")
                }
            }
        } catch {
            Log.sidecar.error("stdout read error: \(error.localizedDescription, privacy: .public)")
        }
        continuation.finish()
    }

    private func send(_ req: SidecarRequest) throws {
        guard let h = stdinHandle else {
            throw TranscriptionError.sidecarNotRunning
        }
        var data = try JSONEncoder().encode(req)
        data.append(0x0A) // \n
        try h.write(contentsOf: data)
    }

    private func nextResponse(timeout seconds: TimeInterval) async throws -> SidecarResponse {
        guard let stream = responseStream else {
            throw TranscriptionError.sidecarNotRunning
        }
        return try await withThrowingTaskGroup(of: SidecarResponse.self) { group in
            group.addTask {
                for await resp in stream { return resp }
                throw TranscriptionError.protocolError("stream closed")
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TranscriptionError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
