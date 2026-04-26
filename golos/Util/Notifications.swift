import UserNotifications

enum Notifications {
    static func requestAuth() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch { return false }
    }

    @MainActor
    static func show(title: String, body: String) {
        guard AppSettings.shared.notifications else { return }
        Task {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }
}
