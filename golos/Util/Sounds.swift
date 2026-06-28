import AppKit

enum Sounds {
    @MainActor static func recordStart() { play("Glass") }
    @MainActor static func recordStop()  { play("Pop") }

    @MainActor private static func play(_ name: String) {
        guard AppSettings.shared.startSound else { return }
        NSSound(named: name)?.play()
    }
}
