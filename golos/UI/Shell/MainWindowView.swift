import SwiftUI
import AppKit

/// Следит за системной темой (Light/Dark) независимо от того, какой appearance
/// навязан окну. `NSApp.effectiveAppearance` отражает именно системную настройку
/// (мы переопределяем appearance окна через `.preferredColorScheme`, а не приложения),
/// поэтому для режима «Авто» она даёт настоящую системную тему.
@MainActor
final class SystemAppearance: ObservableObject {
    @Published private(set) var scheme: ColorScheme
    private var token: NSObjectProtocol?

    init() {
        scheme = SystemAppearance.current()
        token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheme = SystemAppearance.current() }
        }
    }

    @MainActor static func current() -> ColorScheme {
        let best = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return best == .darkAqua ? .dark : .light
    }
}

/// Оболочка главного окна в стиле Codex: серый сайдбар + белый контент
/// со скруглёнными левыми углами (radius 18) и лёгкой тенью слева.
///
/// Тема: эффективная схема вычисляется явно (`.light`/`.dark`) — для «Авто»
/// берётся системная тема из `SystemAppearance`. В `.preferredColorScheme`
/// всегда уходит явное значение, никогда `nil` — иначе SwiftUI не сбрасывает
/// ранее навязанный appearance окна и «Авто» залипает на последней теме.
struct MainWindowView: View {
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var system = SystemAppearance()
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selection: SidebarSection = .general

    private var effectiveScheme: ColorScheme {
        switch settings.themeMode {
        case .auto:  return system.scheme
        case .light: return .light
        case .dark:  return .dark
        }
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
        .preferredColorScheme(effectiveScheme)
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
