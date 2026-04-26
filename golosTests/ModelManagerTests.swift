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

    @MainActor
    @Test func isInstalledChecksFilesExistWithUnknownSize() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let desc = ModelDescriptor(id: "test_model", displayName: "T", files: [
            ModelFile(url: URL(string: "https://example.com/x")!, relativePath: "x.bin", sha256: nil, sizeBytes: nil)
        ])
        let mgr = TestableModelManager(rootOverride: tmp)
        // Файла ещё нет — isInstalled == false
        #expect(mgr.isInstalled(desc) == false)

        // Создать файл — isInstalled == true
        let dest = tmp.appendingPathComponent("test_model").appendingPathComponent("x.bin")
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1,2,3]).write(to: dest)
        #expect(mgr.isInstalled(desc) == true)
    }
}

@MainActor
final class TestableModelManager: ModelManager {
    private let rootOverride: URL
    init(rootOverride: URL) { self.rootOverride = rootOverride; super.init() }
    override func modelDir(_ id: String) -> URL {
        rootOverride.appendingPathComponent(id, isDirectory: true)
    }
}
