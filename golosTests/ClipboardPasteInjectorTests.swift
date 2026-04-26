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
}
