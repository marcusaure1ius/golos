import SwiftUI

struct BannerView: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.yellow.opacity(0.15))
    }
}

struct SettingsRoot: View {
    @State private var selection: SidebarSection = .general
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if let issue = coordinator.permissionIssue {
                BannerView(message: issue)
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
