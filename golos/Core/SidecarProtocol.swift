import Foundation

/// Управляющие сообщения от Swift app → sidecar (по stdin sidecar'а, JSON-lines).
enum SidecarRequest: Encodable, Equatable {
    case load(modelPath: String)
    case beginSession
    case endSession(samplesTotal: UInt64)
    case cancel
    case shutdown

    private enum CodingKeys: String, CodingKey {
        case type
        case modelPath = "model_path"
        case samplesTotal = "samples_total"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .load(let p):
            try c.encode("load", forKey: .type)
            try c.encode(p, forKey: .modelPath)
        case .beginSession:
            try c.encode("begin_session", forKey: .type)
        case .endSession(let total):
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
    case ready
    case sessionStarted
    case partial(text: String)
    case final(text: String, durationMs: UInt64)
    case cancelled
    case error(kind: String, message: String)

    private enum CodingKeys: String, CodingKey {
        case type, version, text, kind, message
        case durationMs = "duration_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            self = .hello(version: try c.decode(String.self, forKey: .version))
        case "ready":
            self = .ready
        case "session_started":
            self = .sessionStarted
        case "partial":
            self = .partial(text: try c.decode(String.self, forKey: .text))
        case "final":
            self = .final(
                text: try c.decode(String.self, forKey: .text),
                durationMs: try c.decode(UInt64.self, forKey: .durationMs)
            )
        case "cancelled":
            self = .cancelled
        case "error":
            self = .error(
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
