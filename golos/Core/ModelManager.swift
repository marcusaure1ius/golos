import Foundation
import CryptoKit

/// Состояние одной загрузки.
struct ModelDownloadProgress: Equatable {
    let bytesDownloaded: Int64
    let bytesTotal: Int64
    var fraction: Double {
        guard bytesTotal > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(bytesTotal)
    }
}

/// Описание одной модели (несколько файлов в одном bundle).
struct ModelDescriptor {
    let id: String              // "e2e_ctc"
    let displayName: String     // "Качество" / "Скорость"
    let files: [ModelFile]      // model.onnx, vocab.txt, ...
}

struct ModelFile {
    let url: URL
    let relativePath: String
    let sha256: String?         // optional verification
    let sizeBytes: Int64?       // nil = неизвестно до загрузки
}

@MainActor
class ModelManager: ObservableObject {
    @Published private(set) var progress: ModelDownloadProgress?
    @Published private(set) var error: String?

    /// Каталог конкретной модели.
    func modelDir(_ id: String) -> URL {
        AppPaths.modelDir(id)
    }

    /// Установлена ли модель локально (все файлы существуют; размер проверяется только если известен).
    func isInstalled(_ desc: ModelDescriptor) -> Bool {
        let dir = modelDir(desc.id)
        for f in desc.files {
            let path = dir.appendingPathComponent(f.relativePath)
            guard FileManager.default.fileExists(atPath: path.path) else { return false }
            if let expected = f.sizeBytes,
               let attr = try? FileManager.default.attributesOfItem(atPath: path.path),
               let size = attr[.size] as? Int64,
               size != expected {
                return false
            }
        }
        return true
    }

    func surfaceError(_ message: String) { error = message }

    func download(_ desc: ModelDescriptor) async throws {
        error = nil
        do {
            let dir = modelDir(desc.id)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let knownTotal = desc.files.compactMap(\.sizeBytes).reduce(0, +)
            progress = ModelDownloadProgress(bytesDownloaded: 0, bytesTotal: knownTotal)

            for f in desc.files {
                let dest = dir.appendingPathComponent(f.relativePath)
                try await downloadFile(f, to: dest, onChunk: { chunkSize in
                    Task { @MainActor [weak self] in
                        guard let self, let p = self.progress else { return }
                        self.progress = .init(bytesDownloaded: p.bytesDownloaded + Int64(chunkSize),
                                              bytesTotal: p.bytesTotal)
                    }
                })
            }
            progress = nil
        } catch {
            self.error = error.localizedDescription
            progress = nil
            throw error
        }
    }

    private func downloadFile(_ file: ModelFile, to dest: URL, onChunk: @escaping (Int) -> Void) async throws {
        let existing = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
        if let expected = file.sizeBytes, existing == expected {
            // Уже скачано полностью.
            return
        }

        var req = URLRequest(url: file.url)
        for (k, v) in Self.makeResumeHeaders(existingBytes: existing) {
            req.setValue(v, forHTTPHeaderField: k)
        }

        // Чанковая загрузка через URLSessionDataDelegate: данные приходят блоками
        // (Data), а не по одному байту. Побайтовый `URLSession.AsyncBytes` упирался
        // в CPU и давал ~1/10 скорости сети на больших файлах (модель ~886 МБ).
        let delegate = StreamingDownloadDelegate(
            dest: dest,
            resumeFromExisting: existing,
            expectedSha: file.sha256,
            onChunk: onChunk,
            onTotal: { [weak self] total in
                // Обновим total только если он был неизвестен.
                Task { @MainActor [weak self] in
                    guard let self, let p = self.progress, p.bytesTotal == 0 else { return }
                    self.progress = .init(bytesDownloaded: p.bytesDownloaded, bytesTotal: total)
                }
            }
        )
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.start(continuation: cont, session: session, request: req)
        }
    }

    nonisolated static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return bytesToHex(Data(digest))
    }

    nonisolated static func bytesToHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func makeResumeHeaders(existingBytes: Int64) -> [String: String] {
        guard existingBytes > 0 else { return [:] }
        return ["Range": "bytes=\(existingBytes)-"]
    }
}

// MARK: Модель GigaAM-v3 (единственная)

extension ModelDescriptor {
    /// Единственная модель — GigaAM-v3 e2e CTC (ONNX), со встроенной пунктуацией/нормализацией.
    /// Источник: https://huggingface.co/istupakov/gigaam-v3-onnx (MIT, ONNX-конверсия GigaAM-v3
    /// от SaluteDevices). sha256/размеры сверены с HF tree API. Файлы сохраняются как
    /// model.onnx + vocab.txt — именно их ждёт GigaAMModel::load в sidecar при FP32.
    static let gigaam = ModelDescriptor(
        id: "e2e_ctc",
        displayName: "GigaAM-v3",
        files: [
            ModelFile(
                url: URL(string: "https://huggingface.co/istupakov/gigaam-v3-onnx/resolve/main/v3_e2e_ctc.onnx")!,
                relativePath: "model.onnx",
                sha256: "377701bd33568f4733feec2db5b2dc12544fd09a5a5dfa69ccf55d161f84027a",
                sizeBytes: 885_950_079
            ),
            ModelFile(
                url: URL(string: "https://huggingface.co/istupakov/gigaam-v3-onnx/resolve/main/v3_e2e_ctc_vocab.txt")!,
                relativePath: "vocab.txt",
                sha256: "142de7570b3de5b3035ce111a89c228e80e6085273731d944093ddf24fa539cd",
                sizeBytes: 2007
            ),
        ]
    )
}

// MARK: Чанковая потоковая загрузка

/// Делегат потоковой загрузки: пишет приходящие блоки `Data` в файл, считает
/// sha256, репортит прогресс. Заменяет побайтовый `URLSession.AsyncBytes`, который
/// упирался в CPU. Колбэки URLSession приходят на своей serial-очереди, так что
/// мутабельное состояние не гоняется конкурентно.
private final class StreamingDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let dest: URL
    private let resumeFromExisting: Int64
    private let expectedSha: String?
    private let onChunk: (Int) -> Void
    private let onTotal: (Int64) -> Void

    private var handle: FileHandle?
    private var hasher = SHA256()
    private var appending = false
    private var finished = false
    private var continuation: CheckedContinuation<Void, Error>?

    init(dest: URL, resumeFromExisting: Int64, expectedSha: String?,
         onChunk: @escaping (Int) -> Void, onTotal: @escaping (Int64) -> Void) {
        self.dest = dest
        self.resumeFromExisting = resumeFromExisting
        self.expectedSha = expectedSha
        self.onChunk = onChunk
        self.onTotal = onTotal
    }

    func start(continuation: CheckedContinuation<Void, Error>, session: URLSession, request: URLRequest) {
        self.continuation = continuation
        session.dataTask(with: request).resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            finish(throwing: NSError(domain: "ModelManager", code: -1)); completionHandler(.cancel); return
        }
        guard http.statusCode == 200 || http.statusCode == 206 else {
            finish(throwing: NSError(domain: "ModelManager", code: http.statusCode,
                                     userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))
            completionHandler(.cancel); return
        }
        appending = (http.statusCode == 206)
        let contentLength = http.expectedContentLength  // -1 если неизвестно
        if !appending, contentLength > 0 { onTotal(contentLength) }

        if !appending || !FileManager.default.fileExists(atPath: dest.path) {
            FileManager.default.createFile(atPath: dest.path, contents: nil)
        }
        do {
            let h = try FileHandle(forWritingTo: dest)
            if appending { try h.seekToEnd() }
            handle = h
        } catch {
            finish(throwing: error); completionHandler(.cancel); return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let handle else { return }
        do {
            try handle.write(contentsOf: data)
            hasher.update(data: data)
            onChunk(data.count)
        } catch {
            finish(throwing: error)
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.close()
        handle = nil
        if finished { return }
        if let error { finish(throwing: error); return }
        // SHA проверка корректна только при полной (не resume) загрузке.
        if let expectedSha, resumeFromExisting == 0 {
            let got = ModelManager.bytesToHex(Data(hasher.finalize()))
            if got != expectedSha {
                try? FileManager.default.removeItem(at: dest)
                finish(throwing: NSError(domain: "ModelManager", code: -2,
                                         userInfo: [NSLocalizedDescriptionKey: "sha256 mismatch: \(got) vs \(expectedSha)"]))
                return
            }
        }
        finish(throwing: nil)
    }

    private func finish(throwing error: Error?) {
        guard !finished else { return }
        finished = true
        if let error { continuation?.resume(throwing: error) } else { continuation?.resume() }
        continuation = nil
    }
}
