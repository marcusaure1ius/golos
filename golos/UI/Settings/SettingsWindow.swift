import SwiftUI

struct SettingsRoot: View {
    @State private var selection: SidebarSection = .general

    var body: some View {
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
        .frame(minWidth: 920, minHeight: 600)
    }
}
