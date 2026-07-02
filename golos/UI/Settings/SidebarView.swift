import SwiftUI

enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case history, dictionary, stats
    case general, hotkeys, microphone, about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .history:    return "История"
        case .dictionary: return "Словарь"
        case .stats:      return "Статистика"
        case .general:    return "Общее"
        case .hotkeys:    return "Горячие клавиши"
        case .microphone: return "Микрофон"
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
        case .about:      return "info.circle"
        }
    }
    var disabled: Bool {
        self == .dictionary
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection
    @Environment(\.palette) var p

    private let transcriptionItems: [SidebarSection] = [.history, .dictionary, .stats]
    private let settingsItems: [SidebarSection] = [.general, .hotkeys, .microphone, .about]

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
        // Полупрозрачная вибрантность + лёгкий тон палитры сверху (чтобы «слегка», а не насквозь).
        .background {
            VisualEffectView(material: .sidebar)
                .overlay(p.sidebar.opacity(0.2))
        }
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
