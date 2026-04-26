import Testing
import Foundation
@testable import golos

// Моки для зависимостей.
final class MockTranscriptionProvider: TranscriptionProvider, @unchecked Sendable {
    var startCalledWith: URL?
    var beginCalled = false
    var feedBytes: Int = 0
    var finalizeReturn: Transcript = .init(text: "тест", durationMs: 100)
    var cancelCalled = false
    var partials: AsyncStream<String> = AsyncStream { _ in }

    func start(modelDir: URL) async throws { startCalledWith = modelDir }
    func beginSession() async throws { beginCalled = true }
    func feed(samples: Data) throws { feedBytes += samples.count }
    func finalize() async throws -> Transcript { finalizeReturn }
    func cancel() async { cancelCalled = true }
    func shutdown() async {}
}

final class MockTextInjector: TextInjector, @unchecked Sendable {
    var injected: [String] = []
    var outcome: InjectionOutcome = .injected
    @MainActor
    func inject(text: String) async -> InjectionOutcome {
        injected.append(text); return outcome
    }
}

@Suite(.serialized)
struct DictationCoordinatorTests {
    @MainActor
    @Test func pttFlowEndToEnd() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed)
        // Симулируем небольшую запись:
        c.feed(samples: Data(count: 320))
        // Подождать чтобы beginSession отработал в Task.
        try await Task.sleep(nanoseconds: 50_000_000)
        // Теперь release должен пройти проверку min length.
        try await Task.sleep(nanoseconds: 200_000_000)
        c.handle(.pttReleased)
        // Дать таскам провернуться.
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(inj.injected == ["тест"])
        #expect(c.state == .idle)
    }

    @MainActor
    @Test func pttUnderMinimumLengthCancels() async throws {
        let prov = MockTranscriptionProvider()
        let inj = MockTextInjector()
        let c = DictationCoordinator(provider: prov, injector: inj, minSessionMs: 200)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.pttPressed)
        // Симулируем релиз через 50ms.
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
        let c = DictationCoordinator(provider: prov, injector: inj)
        try await c.warmup(modelDir: URL(fileURLWithPath: "/tmp/model"))

        c.handle(.toggleTriggered)
        try await Task.sleep(nanoseconds: 250_000_000)
        c.handle(.toggleTriggered)
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(prov.beginCalled)
        #expect(inj.injected == ["тест"])
        #expect(c.state == .idle)
    }
}
