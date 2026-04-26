import AppKit

protocol TextInjector {
    /// Вставить текст в текущее фокусное поле. Возвращает true, если вставка
    /// произошла; false — если поле не найдено и текст положен в clipboard.
    @MainActor
    func inject(text: String) async -> InjectionOutcome
}

enum InjectionOutcome {
    /// Текст успешно вставлен в фокусное поле.
    case injected
    /// Фокус не на текстовом поле — текст положен в clipboard, надо показать notification.
    case copiedToClipboard
    /// Не получилось ни вставить, ни скопировать (что-то совсем плохое).
    case failed(String)
}
