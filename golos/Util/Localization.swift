import Foundation

/// Удобный wrapper для NSLocalizedString — даёт type-safe доступ к строкам.
enum L10n {
    static func string(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }

    // Часто используемые строки — пополняем по мере появления.
    static let pillListening    = string("pill.listening", comment: "слушаю…")
    static let pillTranscribing = string("pill.transcribing", comment: "расшифровываю")
    static let pillToggleStop   = string("pill.toggle.stop", comment: "двойной ⌥ — стоп")
    static let pillError        = string("pill.error", comment: "не получилось")

    static let notifClipboard      = string("notif.clipboard.title", comment: "Транскрипт скопирован")
    static let notifClipboardBody  = string("notif.clipboard.body", comment: "Курсор не на текстовом поле — текст в буфере обмена")
    static let notifMicUnavailable = string("notif.mic.unavailable", comment: "Микрофон недоступен")
    static let notifTranscribeTimeout = string("notif.transcribe.timeout", comment: "Транскрипция заняла слишком долго")
    static let notifModelNotLoaded = string("notif.model.notLoaded", comment: "Модель не загружена")
}
