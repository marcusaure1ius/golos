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
}
