import SwiftUI

enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case history, dictionary, stats
    case general, hotkeys, microphone, models, privacy, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .history:    return "История"
        case .dictionary: return "Словарь"
        case .stats:      return "Статистика"
        case .general:    return "Общее"
        case .hotkeys:    return "Хоткеи"
        case .microphone: return "Микрофон"
        case .models:     return "Модели"
        case .privacy:    return "Приватность"
        case .about:      return "О приложении"
        }
    }
    var systemImage: String {
        switch self {
        case .history:    return "clock"
        case .dictionary: return "text.book.closed"
        case .stats:      return "chart.bar"
        case .general:    return "gearshape"
        case .hotkeys:    return "keyboard"
        case .microphone: return "mic"
        case .models:     return "shippingbox"
        case .privacy:    return "lock.shield"
        case .about:      return "info.circle"
        }
    }
    var iconTint: Color {
        switch self {
        case .history:    return .blue
        case .dictionary: return .teal
        case .stats:      return .purple
        case .general:    return .gray
        case .hotkeys:    return .indigo
        case .microphone: return .red
        case .models:     return .orange
        case .privacy:    return .green
        case .about:      return .cyan
        }
    }
    var disabled: Bool {
        self == .dictionary || self == .stats
    }
    var disabledLabel: String? { disabled ? "скоро" : nil }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection
    let dictationGroups: [SidebarSection] = [.history, .dictionary, .stats]
    let settingsGroups: [SidebarSection] = [.general, .hotkeys, .microphone, .models, .privacy, .about]

    var body: some View {
        List(selection: $selection) {
            Section("Транскрипция") {
                ForEach(dictationGroups) { item(for: $0) }
            }
            Section("Настройки") {
                ForEach(settingsGroups) { item(for: $0) }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private func item(for s: SidebarSection) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(s.iconTint.gradient)
                Image(systemName: s.systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 22, height: 22)

            Text(s.title)

            if let dl = s.disabledLabel {
                Spacer()
                Text(dl).font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(s.disabled ? 0.45 : 1)
        .tag(s)
    }
}
