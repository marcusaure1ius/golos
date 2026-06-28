import SwiftUI

/// Оболочка главного окна в стиле Codex: серый сайдбар + белый контент
/// со скруглёнными левыми углами (radius 18) и лёгкой тенью слева.
///
/// Тема: `.preferredColorScheme` применяется здесь, на родителе, а контент
/// (`MainWindowContent`) ниже читает уже **результирующий** `colorScheme`.
/// Для `.auto` (preferredColorScheme == nil) это настоящая системная тема —
/// без этого разнесения чтение и навязывание темы в одном вью даёт петлю,
/// и «Авто» залипает на последней принудительной теме.
struct MainWindowView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        MainWindowContent()
            .preferredColorScheme(settings.themeMode.preferredColorScheme)
    }
}

private struct MainWindowContent: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selection: SidebarSection = .general

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            // Баннер разрешений (если есть)
            if let issue = coordinator.permissionIssue {
                BannerView(
                    text: issue,
                    action: ("Открыть настройки", { Permissions.openInputMonitoringSettings() })
                )
                Divider()
            }

            HStack(spacing: 0) {
                SidebarView(selection: $selection)

                // Контентная область со скруглёнными левыми углами
                contentPane(p: p)
            }
        }
        .background(p.sidebar)
        .environment(\.palette, p)
        .frame(minWidth: 1000, minHeight: 680)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func contentPane(p: Palette) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
        ZStack {
            paneView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.content)
        .clipShape(shape)
        .overlay {
            // Hairline по контуру скруглённого левого края (следует за углами)
            shape.stroke(p.border, lineWidth: 1)
        }
        .shadow(
            color: scheme == .dark ? .black.opacity(0.4) : .black.opacity(0.07),
            radius: 16,
            x: -5
        )
    }

    @ViewBuilder
    private var paneView: some View {
        switch selection {
        case .history:    HistoryPane()
        case .dictionary: ContentUnavailableView("Скоро", systemImage: "text.book.closed")
        case .stats:      ContentUnavailableView("Скоро", systemImage: "chart.bar")
        case .general:    GeneralPane()
        case .hotkeys:    HotkeysPane()
        case .microphone: MicrophonePane()
        case .models:     ModelsPane()
        case .privacy:    PrivacyPane()
        case .about:      AboutPane()
        }
    }
}
