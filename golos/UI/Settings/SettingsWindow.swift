import SwiftUI

struct BannerView: View {
    let text: String
    let action: (String, () -> Void)?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.system(size: 12))
            Spacer()
            if let (label, fn) = action {
                Button(label, action: fn)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.1))
    }
}

struct SettingsRoot: View {
    @State private var selection: SidebarSection = .general
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if let issue = coordinator.permissionIssue {
                BannerView(
                    text: issue,
                    action: ("Открыть настройки", { Permissions.openInputMonitoringSettings() })
                )
                Divider()
            }
            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
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
        .frame(minWidth: 920, minHeight: 600)
    }
}
