import Foundation
import SwiftUI

/// Единственный источник пользовательских настроек, обёртки над @AppStorage.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum ModelMode: String, CaseIterable, Identifiable {
        case quality = "quality"
        case speed   = "speed"
        var id: String { rawValue }
        var modelId: String { self == .quality ? "e2e_rnnt" : "e2e_ctc" }
    }

    enum ThemeMode: String, CaseIterable, Identifiable {
        case auto, light, dark
        var id: String { rawValue }
        var title: String { ["auto":"Авто","light":"Светлая","dark":"Тёмная"][rawValue]! }
        var preferredColorScheme: ColorScheme? {
            switch self { case .auto: return nil; case .light: return .light; case .dark: return .dark }
        }
    }

    @AppStorage("model.mode")            var modelMode: ModelMode = .quality
    @AppStorage("ui.themeMode")          var themeMode: ThemeMode = .auto
    @AppStorage("hotkey.holdMs")         var holdMs: Int = 200
    @AppStorage("hotkey.doubleTapMs")    var doubleTapMs: Int = 300
    @AppStorage("hotkey.keycode")        var hotkeyKeycode: Int = 0x3D
    @AppStorage("audio.deviceUid")       var deviceUid: String = ""
    @AppStorage("audio.noiseReduction")  var noiseReduction: Bool = false
    @AppStorage("ui.notifications")      var notifications: Bool = true
    @AppStorage("ui.autolaunch")         var autolaunch: Bool = false
    @AppStorage("ui.menuBarIcon")        var menuBarIcon: Bool = true
    @AppStorage("ui.startSound")         var startSound: Bool = false
    @AppStorage("privacy.diagnostics")   var diagnostics: Bool = false
    @AppStorage("ui.firstRun")           var firstRun: Bool = true
    @AppStorage("ui.onboardingSkipped")  var onboardingSkipped: Bool = false
    @AppStorage("ui.onboardingCompleted") var onboardingCompleted: Bool = false

    private init() {}
}

extension AppSettings.ModelMode {
    var descriptor: ModelDescriptor {
        switch self {
        case .quality: return .gigaamRnnt
        case .speed:   return .gigaamCtc
        }
    }
}
