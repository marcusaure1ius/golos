import Testing
import Foundation
@testable import golos

@Suite struct ModelManagerTests {

    @Test func sha256OfKnownString() {
        let data = "hello".data(using: .utf8)!
        let hex = ModelManager.sha256Hex(data)
        #expect(hex == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test func resumeRangeHeaderUsesExistingFileSize() {
        let h = ModelManager.makeResumeHeaders(existingBytes: 1024)
        #expect(h["Range"] == "bytes=1024-")
    }

    @Test func noRangeHeaderWhenNoExistingFile() {
        let h = ModelManager.makeResumeHeaders(existingBytes: 0)
        #expect(h["Range"] == nil)
    }
}
