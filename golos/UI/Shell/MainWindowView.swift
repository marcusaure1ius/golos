import SwiftUI

/// Оболочка главного окна в стиле Codex: серый сайдбар + белый контент
/// со скруглёнными левыми углами (radius 18) и лёгкой тенью слева.
struct MainWindowView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var systemScheme
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selection: SidebarSection = .general

    private var effectiveScheme: ColorScheme {
        settings.themeMode.preferredColorScheme ?? systemScheme
    }

    var body: some View {
        let p = Palette.of(effectiveScheme)
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
        .preferredColorScheme(settings.themeMode.preferredColorScheme)
        .frame(minWidth: 1000, minHeight: 680)
    }

    @ViewBuilder
    private func contentPane(p: Palette) -> some View {
        ZStack {
            paneView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.content)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        )
        .overlay(alignment: .leading) {
            // Однопиксельный hairline по левому краю контентной области
            Rectangle()
                .fill(p.border)
                .frame(width: 1)
        }
        .shadow(
            color: effectiveScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.07),
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
