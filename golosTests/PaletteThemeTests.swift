import Testing
import SwiftUI
@testable import golos

@Suite struct PaletteTests {
    @Test func lightAndDarkDiffer() {
        #expect(Palette.of(.light).content != Palette.of(.dark).content)
        #expect(Palette.light.accent == Color(hex: 0x0a84ff))
    }
}

@Suite struct ThemeModeTests {
    @Test func themeModeMapping() {
        #expect(AppSettings.ThemeMode.auto.preferredColorScheme == nil)
        #expect(AppSettings.ThemeMode.dark.preferredColorScheme == .dark)
        #expect(AppSettings.ThemeMode.light.preferredColorScheme == .light)
    }
}
