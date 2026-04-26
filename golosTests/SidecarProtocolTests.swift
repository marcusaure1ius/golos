import Foundation
import Testing
@testable import golos

struct SidecarProtocolTests {
    @Test func loadRequestEncodesAsExpected() throws {
        let req = SidecarRequest.load(modelPath: "/tmp/m")
        let json = try JSONEncoder().encode(req)
        let str = String(data: json, encoding: .utf8)!
        #expect(str.contains(#""type":"load""#))
        #expect(str.contains(#""model_path":"\/tmp\/m""#) || str.contains(#""model_path":"/tmp/m""#))
    }

    @Test func beginSessionEncodesAsTagOnly() throws {
        let req = SidecarRequest.beginSession
        let str = String(data: try JSONEncoder().encode(req), encoding: .utf8)!
        #expect(str == #"{"type":"begin_session"}"#)
    }

    @Test func helloResponseDecodes() throws {
        let raw = #"{"type":"hello","version":"0.1.0"}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .hello(let v) = resp else { Issue.record("not hello"); return }
        #expect(v == "0.1.0")
    }

    @Test func finalResponseDecodes() throws {
        let raw = #"{"type":"final","text":"привет","duration_ms":1234}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .final(let text, let ms) = resp else { Issue.record("not final"); return }
        #expect(text == "привет")
        #expect(ms == 1234)
    }

    @Test func errorResponseDecodes() throws {
        let raw = #"{"type":"error","kind":"model_not_loaded","message":"x"}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .error(let kind, let msg) = resp else { Issue.record("not error"); return }
        #expect(kind == "model_not_loaded")
        #expect(msg == "x")
    }
}
