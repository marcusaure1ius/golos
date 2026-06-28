import SwiftUI

enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case history, dictionary, stats
    case general, hotkeys, microphone, models, about

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
        case .about:      return "info.circle"
        }
    }
    var disabled: Bool {
        self == .dictionary || self == .stats
    }
    var disabledLabel: String? { disabled ? "скоро" : nil }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection
    @Environment(\.palette) var p

    private let transcriptionItems: [SidebarSection] = [.history, .dictionary, .stats]
    private let settingsItems: [SidebarSection] = [.general, .hotkeys, .microphone, .models, .about]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Отступ под светофор
                Spacer().frame(height: 48)

                // Группа «Транскрипция»
                groupHeader("Транскрипция")
                ForEach(transcriptionItems) { section in
                    navRow(for: section)
                }

                Spacer().frame(height: 16)

                // Группа «Настройки»
                groupHeader("Настройки")
                ForEach(settingsItems) { section in
                    navRow(for: section)
                }

                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 250)
        .background(p.sidebar)
    }

    @ViewBuilder
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(p.muted)
            .padding(.horizontal, 9)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func navRow(for section: SidebarSection) -> some View {
        let isSelected = selection == section
        GNavRow(
            icon: section.systemImage,
            title: section.title,
            selected: isSelected,
            disabled: section.disabled,
            soon: section.disabled
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !section.disabled else { return }
            selection = section
        }
    }
}
