import SwiftUI

@main
struct GolosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        // Главное окно с настройками — открывается из menu bar или ⌘,
        Window("Настройки golos", id: "settings") {
            SettingsRoot()
                .environmentObject(coordinator)
                .task { bootstrapIfNeeded() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Настройки…") { openWindow(id: "settings") }
                    .keyboardShortcut(",")
            }
        }

        // Onboarding — открывается на первом запуске или из настроек
        Window("Настройка golos", id: "onboarding") {
            OnboardingRoot()
                .environmentObject(coordinator)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    @MainActor
    private func bootstrapIfNeeded() {
        coordinator.start(
            openSettings: { openWindow(id: "settings") },
            openOnboarding: { openWindow(id: "onboarding") }
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Запретить выход при закрытии последнего окна — у нас menu bar app.
        NSApp.setActivationPolicy(.accessory)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen → открыть Settings.
        true
    }
}
