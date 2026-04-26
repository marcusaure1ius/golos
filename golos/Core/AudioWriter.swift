import Foundation

/// Сериализует запись PCM-чанков в audio-fd. Все enqueue гарантированно
/// будут записаны до того, как flush() вернётся.
actor AudioWriter {
    private let handle: FileHandle
    private var pending: [Data] = []
    private var isOpen = true
    private var writerTask: Task<Void, Never>?
    private var pendingContinuations: [CheckedContinuation<Void, Never>] = []

    init(fd: Int32) {
        self.handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        self.writerTask = Task { await self.writeLoop() }
    }

    func enqueue(_ data: Data) {
        guard isOpen else { return }
        pending.append(data)
    }

    /// Дождаться, что все ранее enqueued чанки записаны в pipe.
    func flush() async {
        guard isOpen else { return }
        if pending.isEmpty { return }
        await withCheckedContinuation { cont in
            pendingContinuations.append(cont)
        }
    }

    func close() async {
        isOpen = false
        writerTask?.cancel()
        await writerTask?.value
        try? handle.close()
        // Разбудить ожидающих flush().
        for c in pendingContinuations { c.resume() }
        pendingContinuations.removeAll()
    }

    private func writeLoop() async {
        while !Task.isCancelled {
            if let chunk = pending.first {
                pending.removeFirst()
                do { try handle.write(contentsOf: chunk) }
                catch { Log.audio.error("AudioWriter write failed: \(error.localizedDescription, privacy: .public)") }
            } else {
                if !pendingContinuations.isEmpty {
                    let conts = pendingContinuations
                    pendingContinuations.removeAll()
                    for c in conts { c.resume() }
                }
                // Yield чтобы другие enqueue/flush получили слот.
                await Task.yield()
            }
        }
    }
}
