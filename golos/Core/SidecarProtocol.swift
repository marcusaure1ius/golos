import Foundation

/// Управляющие сообщения от Swift app → sidecar (по stdin sidecar'а, JSON-lines).
enum SidecarRequest: Encodable, Equatable {
    case load(id: UInt64, modelPath: String)
    case beginSession(id: UInt64, biasTerms: [String])
    case endSession(id: UInt64, samplesTotal: UInt64)
    case cancel(id: UInt64)
    case shutdown(id: UInt64)

    var id: UInt64 {
        switch self {
        case .load(let i, _): return i
        case .beginSession(let i, _): return i
        case .endSession(let i, _): return i
        case .cancel(let i): return i
        case .shutdown(let i): return i
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, id
        case modelPath = "model_path"
        case samplesTotal = "samples_total"
        case biasTerms = "bias_terms"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        switch self {
        case .load(_, let p):
            try c.encode("load", forKey: .type)
            try c.encode(p, forKey: .modelPath)
        case .beginSession(_, let terms):
            try c.encode("begin_session", forKey: .type)
            if !terms.isEmpty {
                try c.encode(terms, forKey: .biasTerms)
            }
        case .endSession(_, let total):
            try c.encode("end_session", forKey: .type)
            try c.encode(total, forKey: .samplesTotal)
        case .cancel:
            try c.encode("cancel", forKey: .type)
        case .shutdown:
            try c.encode("shutdown", forKey: .type)
        }
    }
}

/// Ответы от sidecar → Swift app (по stdout sidecar'а, JSON-lines).
enum SidecarResponse: Decodable, Equatable {
    case hello(version: String)
    case ready(id: UInt64)
    case sessionStarted(id: UInt64)
    case partial(text: String)
    case final(id: UInt64, text: String, durationMs: UInt64)
    case cancelled(id: UInt64)
    case error(id: UInt64?, kind: String, message: String)

    var id: UInt64? {
        switch self {
        case .hello, .partial: return nil
        case .ready(let i): return i
        case .sessionStarted(let i): return i
        case .cancelled(let i): return i
        case .final(let i, _, _): return i
        case .error(let i, _, _): return i
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, id, version, text, kind, message
        case durationMs = "duration_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let id = try c.decodeIfPresent(UInt64.self, forKey: .id)
        switch type {
        case "hello":
            self = .hello(version: try c.decode(String.self, forKey: .version))
        case "ready":
            self = .ready(id: id ?? 0)
        case "session_started":
            self = .sessionStarted(id: id ?? 0)
        case "partial":
            self = .partial(text: try c.decode(String.self, forKey: .text))
        case "final":
            self = .final(
                id: id ?? 0,
                text: try c.decode(String.self, forKey: .text),
                durationMs: try c.decode(UInt64.self, forKey: .durationMs)
            )
        case "cancelled":
            self = .cancelled(id: id ?? 0)
        case "error":
            self = .error(
                id: id,
                kind: try c.decode(String.self, forKey: .kind),
                message: try c.decode(String.self, forKey: .message)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown response type: \(type)"
            )
        }
    }
}
