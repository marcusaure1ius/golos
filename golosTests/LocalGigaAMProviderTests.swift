import Testing
import Foundation
@testable import golos

@Suite struct LocalGigaAMProviderTests {
    @Test func responseCorrelatorMatchesIds() async throws {
        let cor = ResponseCorrelator()
        let task = Task {
            try await cor.await(id: 7, timeout: 1.0)
        }
        await Task.yield()
        // Stale response — должен быть проигнорирован.
        await cor.deliver(.final(id: 6, text: "old", durationMs: 0))
        // Целевой response.
        await cor.deliver(.final(id: 7, text: "new", durationMs: 100))
        let resp = try await task.value
        if case .final(_, let text, _) = resp { #expect(text == "new") }
        else { Issue.record("expected .final") }
    }

    @Test func correlatorTimesOut() async throws {
        let cor = ResponseCorrelator()
        do {
            _ = try await cor.await(id: 1, timeout: 0.05)
            Issue.record("expected timeout")
        } catch TranscriptionError.timeout { /* ok */ }
        catch { Issue.record("wrong error: \(error)") }
    }

    /// Регрессия на race: sidecar может ответить ДО того, как caller успел зарегистрировать
    /// continuation в `await(id:)`. Если call site сначала expect()'ит id, то ответ,
    /// пришедший в окне между send и await, сохраняется и достаётся следующим await.
    @Test func deliveryBeforeAwaitIsPreservedWhenExpected() async throws {
        let cor = ResponseCorrelator()
        await cor.expect(id: 42)
        await cor.deliver(.final(id: 42, text: "race-fix", durationMs: 0))
        let resp = try await cor.await(id: 42, timeout: 0.5)
        guard case .final(_, let text, _) = resp else {
            Issue.record("expected .final, got \(resp)"); return
        }
        #expect(text == "race-fix")
    }

    /// Без expect() ранний deliver всё ещё дропается — иначе early-bucket мог бы расти на
    /// stale id. expect — явный сигнал "я жду этот id".
    @Test func deliveryWithoutExpectIsDropped() async throws {
        let cor = ResponseCorrelator()
        await cor.deliver(.final(id: 99, text: "stale", durationMs: 0))
        // Теперь expect+await: сохранённого ответа быть не должно — попадаем в timeout.
        await cor.expect(id: 99)
        do {
            _ = try await cor.await(id: 99, timeout: 0.05)
            Issue.record("expected timeout — unexpected delivery should have been dropped")
        } catch TranscriptionError.timeout { /* ok */ }
        catch { Issue.record("wrong error: \(error)") }
    }
}
