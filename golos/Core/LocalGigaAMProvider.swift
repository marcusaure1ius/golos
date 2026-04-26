import Foundation

// MARK: - ResponseCorrelator

/// Maps request id → continuation. Stale responses (unknown id) are silently discarded.
actor ResponseCorrelator {
    private var pending: [UInt64: CheckedContinuation<SidecarResponse, Error>] = [:]

    func deliver(_ resp: SidecarResponse) {
        guard let id = resp.id else { return }  // unsolicited (Hello, Partial) — ignore for request flow
        if let cont = pending.removeValue(forKey: id) {
            cont.resume(returning: resp)
        }
        // Stale id (no waiter) — silently ignore.
    }

    /// Wait for the response matching `id`, or throw TranscriptionError.timeout.
    func `await`(id: UInt64, timeout: TimeInterval) async throws -> SidecarResponse {
        // We store continuation here inside the actor. If we time out we remove it.
        return try await withCheckedThrowingContinuation { cont in
            pending[id] = cont
            // Schedule timeout.
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self.expireIfPending(id: id)
            }
        }
    }

    private func expireIfPending(id: UInt64) {
        if let cont = pending.removeValue(forKey: id) {
            cont.resume(throwing: TranscriptionError.timeout)
        }
    }

    func failAll(_ error: Error) {
        for (_, c) in pending { c.resume(throwing: error) }
        pending.removeAll()
    }
}

// MARK: - LocalGigaAMProvider

/// Реализация TranscriptionProvider, общающаяся с `golos-asr` sidecar
/// через stdin/stdout (JSON-lines) + отдельный pipe для PCM.
@MainActor
final class LocalGigaAMProvider: TranscriptionProvider {
    private let sidecarURL: URL
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?

    /// Pipe для аудио (Swift пишет → sidecar читает). Read-end передаётся sidecar
    /// через --audio-fd, мы (write-end) держим у себя.
    private var writer: AudioWriter?

    private let correlator = ResponseCorrelator()
    private var helloReceived = false
    private var helloWaiters: [CheckedContinuation<Void, Error>] = []

    private let partialsContinuation: AsyncStream<String>.Continuation
    let partials: AsyncStream<String>

    private var isShuttingDown = false
    private var samplesEnqueued: UInt64 = 0
    private var requestCounter: UInt64 = 0

    init(sidecarURL: URL = AppPaths.sidecarBinary) {
        self.sidecarURL = sidecarURL
        var cont: AsyncStream<String>.Continuation!
        self.partials = AsyncStream { c in cont = c }
        self.partialsContinuation = cont
    }

    deinit { partialsContinuation.finish() }

    func start(modelDir: URL) async throws {
        try spawnSidecarIfNeeded()
        try await waitForHello(timeout: 5)
        let id = nextRequestId()
        try send(.load(id: id, modelPath: modelDir.path))
        // ONNX Runtime: graph optimizations + session creation для ~340MB модели
        // могут занимать десятки секунд (особенно холодный старт). 30s недостаточно.
        let resp = try await correlator.await(id: id, timeout: 120)
        switch resp {
        case .ready: return
        case .error(_, _, let msg): throw TranscriptionError.modelLoadFailed(msg)
        default: throw TranscriptionError.protocolError("unexpected after load: \(resp)")
        }
    }

    func beginSession() async throws {
        samplesEnqueued = 0
        let id = nextRequestId()
        try send(.beginSession(id: id))
        let resp = try await correlator.await(id: id, timeout: 5)
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
        let id = nextRequestId()
        try send(.endSession(id: id, samplesTotal: samplesEnqueued))
        let resp = try await correlator.await(id: id, timeout: 30)
        switch resp {
        case .final(_, let text, let ms):
            return Transcript(text: text, durationMs: ms)
        case .error(_, _, let msg):
            throw TranscriptionError.transcribeFailed(msg)
        default:
            throw TranscriptionError.protocolError("unexpected during finalize: \(resp)")
        }
    }

    func cancel() async {
        let id = nextRequestId()
        try? send(.cancel(id: id))
        _ = try? await correlator.await(id: id, timeout: 2)
    }

    func shutdown() async {
        isShuttingDown = true
        let id = nextRequestId()
        try? send(.shutdown(id: id))
        if let w = writer { await w.close() }
        writer = nil
        let proc = process
        process = nil
        await Task.detached { proc?.waitUntilExit() }.value
        await correlator.failAll(TranscriptionError.sidecarNotRunning)
    }

    // MARK: Private

    private func nextRequestId() -> UInt64 {
        requestCounter &+= 1
        return requestCounter
    }

    private func waitForHello(timeout: TimeInterval) async throws {
        if helloReceived { return }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [self] in
                // Re-check inside actor-isolated execution to close TOCTOU window.
                if self.helloReceived { return }
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.helloWaiters.append(cont)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TranscriptionError.timeout
            }
            _ = try await group.next()!
            group.cancelAll()
        }
    }

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

        // Reset hello state for new process.
        helloReceived = false

        let outHandle = stdoutHandle!
        let partialsCont = partialsContinuation
        let correlator = self.correlator
        Task.detached { [weak self] in
            await Self.readResponseLoop(
                handle: outHandle,
                correlator: correlator,
                partials: partialsCont,
                onHello: { Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.helloReceived = true
                    for c in self.helloWaiters { c.resume() }
                    self.helloWaiters.removeAll()
                }}
            )
            await Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isShuttingDown {
                    Log.sidecar.warning("sidecar closed unexpectedly")
                    await correlator.failAll(TranscriptionError.sidecarNotRunning)
                }
            }.value
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
        correlator: ResponseCorrelator,
        partials: AsyncStream<String>.Continuation,
        onHello: @escaping () -> Void
    ) async {
        let decoder = JSONDecoder()
        do {
            for try await line in handle.bytes.lines {
                guard let data = line.data(using: .utf8) else { continue }
                do {
                    let resp = try decoder.decode(SidecarResponse.self, from: data)
                    if case .hello = resp {
                        onHello()
                    } else if case .partial(let text) = resp {
                        partials.yield(text)
                    } else {
                        await correlator.deliver(resp)
                    }
                } catch {
                    Log.sidecar.error("decode error: \(error.localizedDescription, privacy: .public) line=\(line, privacy: .public)")
                }
            }
        } catch {
            Log.sidecar.error("stdout read error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func send(_ req: SidecarRequest) throws {
        guard let h = stdinHandle else {
            throw TranscriptionError.sidecarNotRunning
        }
        var data = try JSONEncoder().encode(req)
        data.append(0x0A) // \n
        try h.write(contentsOf: data)
    }
}
