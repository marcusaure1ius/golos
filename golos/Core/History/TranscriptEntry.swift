import Foundation

/// Запись транскрипции в истории.
struct TranscriptEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let date: Date
}
