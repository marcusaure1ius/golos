import Foundation
import Testing
@testable import golos

struct SidecarProtocolTests {
    @Test func loadRequestEncodesAsExpected() throws {
        let req = SidecarRequest.load(id: 1, modelPath: "/tmp/m")
        let json = try JSONEncoder().encode(req)
        let str = String(data: json, encoding: .utf8)!
        #expect(str.contains(#""type":"load""#))
        #expect(str.contains(#""id":1"#))
        #expect(str.contains(#""model_path":"\/tmp\/m""#) || str.contains(#""model_path":"/tmp/m""#))
    }

    @Test func beginSessionEncodesWithId() throws {
        let req = SidecarRequest.beginSession(id: 2, biasTerms: [])
        let str = String(data: try JSONEncoder().encode(req), encoding: .utf8)!
        #expect(str.contains(#""type":"begin_session""#))
        #expect(str.contains(#""id":2"#))
    }

    @Test func beginSessionEncodesBiasTerms() throws {
        let req = SidecarRequest.beginSession(id: 4, biasTerms: ["GigaAM", "Толк"])
        let str = String(data: try JSONEncoder().encode(req), encoding: .utf8)!
        #expect(str.contains(#""bias_terms""#))
        #expect(str.contains("GigaAM"))
        #expect(str.contains("Толк"))
    }

    @Test func endSessionEncodesWithSamplesTotal() throws {
        let data = try JSONEncoder().encode(SidecarRequest.endSession(id: 3, samplesTotal: 32000))
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"type\":\"end_session\""))
        #expect(json.contains("\"samples_total\":32000"))
        #expect(json.contains("\"id\":3"))
    }

    @Test func helloResponseDecodes() throws {
        let raw = #"{"type":"hello","version":"0.1.0"}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .hello(let v) = resp else { Issue.record("not hello"); return }
        #expect(v == "0.1.0")
    }

    @Test func finalResponseDecodes() throws {
        let raw = #"{"type":"final","id":7,"text":"привет","duration_ms":1234}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .final(let id, let text, let ms) = resp else { Issue.record("not final"); return }
        #expect(id == 7)
        #expect(text == "привет")
        #expect(ms == 1234)
    }

    @Test func errorResponseDecodes() throws {
        let raw = #"{"type":"error","id":null,"kind":"model_not_loaded","message":"x"}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .error(let id, let kind, let msg) = resp else { Issue.record("not error"); return }
        #expect(id == nil)
        #expect(kind == "model_not_loaded")
        #expect(msg == "x")
    }

    @Test func errorResponseWithIdDecodes() throws {
        let raw = #"{"type":"error","id":5,"kind":"bad","message":"oops"}"#
        let resp = try JSONDecoder().decode(SidecarResponse.self, from: raw.data(using: .utf8)!)
        guard case .error(let id, _, _) = resp else { Issue.record("not error"); return }
        #expect(id == 5)
    }
}
