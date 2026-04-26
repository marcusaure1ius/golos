import SwiftUI
import AppKit

@main
struct GolosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Пустая Settings scene удерживает SwiftUI App alive.
        // Реальные окна (settings + onboarding) открывает AppDelegate через NSHostingController.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let coordinator = AppCoordinator()

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        coordinator.start(
            openSettings: { [weak self] in self?.showSettings() },
            openOnboarding: { [weak self] in self?.showOnboarding() }
        )
    }

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsRoot()
                .environmentObject(coordinator))
            let w = NSWindow(contentViewController: host)
            w.title = "Настройки golos"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.identifier = NSUserInterfaceItemIdentifier("settings")
            w.setContentSize(NSSize(width: 920, height: 600))
            w.center()
            w.isReleasedWhenClosed = false
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let host = NSHostingController(rootView: OnboardingRoot()
                .environmentObject(coordinator))
            let w = NSWindow(contentViewController: host)
            w.title = "Настройка golos"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.identifier = NSUserInterfaceItemIdentifier("onboarding")
            w.setContentSize(NSSize(width: 580, height: 580))
            w.center()
            w.isReleasedWhenClosed = false
            onboardingWindow = w
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }
}
