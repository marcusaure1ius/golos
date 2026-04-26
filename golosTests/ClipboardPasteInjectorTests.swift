import Testing
import AppKit
@testable import golos

@Suite(.serialized)  // используем NSPasteboard.general — последовательно
struct ClipboardSaveRestoreTests {

    @Test func saveAndRestoreReturnsExactStringContents() async throws {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("оригинал", forType: .string)

        let snapshot = ClipboardSnapshot.capture(pb)
        pb.clearContents()
        pb.setString("временное", forType: .string)
        #expect(pb.string(forType: .string) == "временное")

        snapshot.restore(to: pb)
        #expect(pb.string(forType: .string) == "оригинал")
    }

    @Test func emptyClipboardRestoresToEmpty() async throws {
        let pb = NSPasteboard.general
        pb.clearContents()
        let snapshot = ClipboardSnapshot.capture(pb)
        pb.setString("temp", forType: .string)

        snapshot.restore(to: pb)
        #expect(pb.string(forType: .string) == nil || pb.string(forType: .string) == "")
    }

    @Test func waitForChangeReturnsTrueAfterMutation() async throws {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("before", forType: .string)
        let initialCount = pb.changeCount

        // Mutate clipboard from a concurrent task after a short delay.
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
            pb.clearContents()
            pb.setString("after", forType: .string)
        }

        let changed = await ClipboardPasteInjector.waitForPasteboardChange(
            pasteboard: pb,
            initialCount: initialCount,
            timeout: 0.5
        )
        #expect(changed == true)
    }
}
