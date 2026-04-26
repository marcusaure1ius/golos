import SwiftUI

@main
struct GolosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Главное окно (Settings) — будет добавлено в Task 15.
        // Сейчас — пустая Scene, чтобы приложение могло запуститься в menu bar mode.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire-up в Task 17.
    }
}
