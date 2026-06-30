import Testing
import Foundation
@testable import golos

// Моки для зависимостей.
final class MockTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    var startCalledWith: URL?
    var startCallCount = 0
    var beginCalled = false
    var feedBytes: Int = 0
    var finalizeReturn: Transcript = .init(text: "тест", durationMs: 100)
    var cancelCalled = false
    var partials: AsyncStream<String> = AsyncStream { _ in }
    /// Порядок вызовов flush/finalize для проверки в тестах.
    var flushOrder: [String] = []

    func start(modelDir: URL) async throws { startCalledWith = modelDir; startCallCount += 1 }
    func resetSampleCounter() { feedBytes = 0 }
    func beginSession() async throws { beginCalled = true }
    func feed(samples: Data) throws { feedBytes += samples.count }
    func flushSamples() async { flushOrder.append("flush") }
    func finalize() async throws -> Transcript { flushOrder.append("finalize"); return finalizeReturn }
    func cancel() async { cancelCalled = true }
    func shutdown() async {}
}

final class MockTextInjector: TextInjector, @unchecked Sendable {
    var injected: [String] = []
    var outcome: InjectionOutcome = .injected
    // Стрим, в который посылается текст при каждом inject — для детерминированного ожидания.
    private let continuation: AsyncStream<String>.Continuation
    let signal: AsyncStream<String>

    init() {
        var cont: AsyncStream<String>.Continuation!
        signal = AsyncStream { cont = $0 }
        continuation = cont
    }

    @MainActor
    func inject(text: String) async -> InjectionOutcome {
        injected.append(text)
        continuation.yield(text)
        return outcome
    }
}

final class FailingMockProvider: TranscriptionProvider, @unchecked Sendable {
    var partials: AsyncStream<String> = AsyncStream { _ in }
    func start(modelDir: URL) async throws {}
    func resetSampleCounter() {}
    func beginSession() async throws { throw TranscriptionError.protocolError("forced") }
    func feed(samples: Data) throws {}
    func flushSamples() async {}
    func finalize() async throws -> Transcript { Transcript(text: "", durationMs: 0) }
    func cancel() async {}
    func shutdown() async {}
}

// MARK: - Вспомогательные детерминированные ожидалки

extension DictationCoordinatorTests {
    /// Ожидает первый элемент из AsyncStream с таймаутом.
    /// Возвращает значение, или nil если таймаут истёк.
    static func firstWithTimeout<T: Sendable>(
        _ stream: AsyncStream<T>,
        timeout: TimeInterval = 2.0
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                for await value in stream { return value }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }
}

@Suite(.serialized)
struct DictationCoordinatorTests {
    @MainActor
    @Test func beginSessionFailureKeepsStateIdle() async throws {
        let prov = FailingMockProvider()
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed)
        // Дать Task провернуться и переустановить state в .error
        try await Task.sleep(nanoseconds: 100_000_000)

        // Не должно быть .recording — beginSession упал.
        if case .recording = c.state { Issue.record("state must not be .recording after beginSession failure"); return }
    }

    /// Regression: если user отпускает хоткей пока beginSession ещё в полёте,
    /// state .preparing → .idle (cancel-path). beginSession Task НЕ должен потом
    /// перезаписать .recording поверх .idle (был phantom-recording баг 2026-04-26).
    @MainActor
    @Test func beginSessionDoesNotOverrideStateAfterRelease() async throws {
        // Slow provider — beginSession висит до явного resume, давая нам окно для UP.
        actor SlowGate {
            var resumed = false
            var continuation: CheckedContinuation<Void, Never>?
            func wait() async {
                if resumed { return }
                await withCheckedContinuation { c in continuation = c }
            }
            func resume() {
                resumed = true
                continuation?.resume()
                continuation = nil
            }
        }
        final class SlowProvider: TranscriptionProvider, @unchecked Sendable {
            let gate: SlowGate
            var partials: AsyncStream<String> = AsyncStream { _ in }
            init(gate: SlowGate) { self.gate = gate }
            func start(modelDir: URL) async throws {}
            func resetSampleCounter() {}
            func beginSession() async throws { await gate.wait() }
            func feed(samples: Data) throws {}
            func flushSamples() async {}
            func finalize() async throws -> Transcript { Transcript(text: "", durationMs: 0) }
            func cancel() async {}
            func shutdown() async {}
        }
        let gate = SlowGate()
        let prov = SlowProvider(gate: gate)
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed) // state .preparing, beginSession Task ждёт gate
        // Имитируем UP пока beginSession ещё в полёте.
        c.handle(.pttReleased)
        #expect(c.state == .idle, "после UP в .preparing state должен быть .idle")
        // Теперь резюмируем beginSession — он попытается поставить .recording.
        await gate.resume()
        try await Task.sleep(nanoseconds: 50_000_000)
        // Guard должен сработать — state остаётся .idle.
        #expect(c.state == .idle, "beginSession не должен перезаписывать .idle на .recording")
    }

    @MainActor
    @Test func pttFlowEndToEnd() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        // minSessionMs: 0 — тест проверяет поток, не wall-clock границу.
        let c = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 0)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed)
        c.feed(samples: Data(count: 320))
        // Ждём перехода в .recording детерминированно (beginSession в Task).
        var isRecording = false
        let recDeadline = Date().addingTimeInterval(1.0)
        while !isRecording && Date() < recDeadline {
            if case .recording = c.state { isRecording = true }
            await Task.yield()
        }
        #expect(isRecording, "должны перейти в .recording")

        c.handle(.pttReleased)

        // Детерминированно ждём первый inject через стрим вместо Task.sleep.
        let injected = await Self.firstWithTimeout(inj.signal, timeout: 2.0)
        #expect(injected == "тест")
        #expect(inj.injected == ["тест"])

        // Ждём .idle.
        let gotIdle = await Self.waitForStateIdle(c, timeout: 2.0)
        #expect(gotIdle, "state must reach .idle")
        #expect(c.state == .idle)
    }

    @MainActor
    @Test func pttUnderMinimumLengthCancels() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 200)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed)
        // Симулируем релиз через 50ms — wall-clock граница, sleep семантически правильный.
        try await Task.sleep(nanoseconds: 50_000_000)
        c.handle(.pttReleased)
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(inj.injected == [])
        #expect(prov.cancelCalled)
        #expect(c.state == .idle)
    }

    @MainActor
    @Test func toggleStartsAndStops() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        // minSessionMs: 0 — чтобы тест проверял поток, а не wall-clock границу.
        let c = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 0)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.toggleTriggered)
        // Ждём .recording детерминированно.
        var isRecording = false
        let recDeadline = Date().addingTimeInterval(1.0)
        while !isRecording && Date() < recDeadline {
            if case .recording = c.state { isRecording = true }
            await Task.yield()
        }
        #expect(isRecording, "должны перейти в .recording после первого toggle")

        c.handle(.toggleTriggered)

        // Детерминированно ждём inject через стрим.
        let injected = await Self.firstWithTimeout(inj.signal, timeout: 2.0)
        #expect(injected == "тест")
        #expect(prov.beginCalled)
        #expect(inj.injected == ["тест"])

        // Ждём .idle.
        let gotIdle = await Self.waitForStateIdle(c, timeout: 2.0)
        #expect(gotIdle, "state must reach .idle")
        #expect(c.state == .idle)
    }

    @Test @MainActor func publishesLastOutcomeAfterDictation() async throws {
        let prov = MockTranscriptionProvider()
        prov.finalizeReturn = .init(text: "привет мир", durationMs: 300)
        let inj = MockTextInjector()
        inj.outcome = .injected
        let coordinator = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 0)

        coordinator.handle(.pttPressed)
        try? await Task.sleep(nanoseconds: 50_000_000)
        coordinator.handle(.pttReleased)
        _ = await Self.firstWithTimeout(inj.signal)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(coordinator.lastOutcome == DictationOutcome(text: "привет мир", outcome: .injected))
    }

    @Test @MainActor func warmupIsIdempotentForSameDir() async throws {
        let prov = MockTranscriptionProvider()
        let coordinator = DictationCoordinator(provider: prov, injector: MockTextInjector())
        let dir = URL(fileURLWithPath: "/tmp/model-x")

        try await coordinator.warmup(modelDir: dir)
        try await coordinator.warmup(modelDir: dir)

        #expect(prov.startCallCount == 1)
    }

    // MARK: - Task 7.2: feed gating и flush ordering

    @MainActor
    @Test func feedIgnoredOutsideRecording() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        // В состоянии .idle — feed должен быть проигнорирован.
        c.feed(samples: Data(count: 320))
        #expect(prov.feedBytes == 0, "feed в .idle должен быть проигнорирован")
    }

    @MainActor
    @Test func flushHappensBeforeFinalize() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        // minSessionMs: 0 — фокус на порядке вызовов, не на wall-clock границе.
        let c = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 0)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.toggleTriggered)
        // Ждём .recording.
        var isRecording = false
        let recDeadline = Date().addingTimeInterval(1.0)
        while !isRecording && Date() < recDeadline {
            if case .recording = c.state { isRecording = true }
            await Task.yield()
        }

        c.handle(.toggleTriggered)

        // Ждём завершения через signal.
        _ = await Self.firstWithTimeout(inj.signal, timeout: 2.0)

        // flush должен быть перед finalize.
        #expect(prov.flushOrder == ["flush", "finalize"],
                "flushSamples должен вызываться до finalize, got: \(prov.flushOrder)")
    }
}

// MARK: - Вспомогательный метод для ожидания .idle (не требует Equatable с ассоциированными значениями)
extension DictationCoordinatorTests {
    @MainActor
    static func waitForStateIdle(
        _ coordinator: DictationCoordinator,
        timeout: TimeInterval = 2.0
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while coordinator.state != .idle {
            if Date() > deadline { return false }
            await Task.yield()
        }
        return true
    }
}
