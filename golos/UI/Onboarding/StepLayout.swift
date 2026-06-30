import SwiftUI

/// Одноколоночный контейнер шага онбординга в строгом стиле приложения:
/// нейтральный тайл-иконка → заголовок → подзаголовок → контент. Цвета из палитры.
struct StepLayout<Content: View>: View {
    @Environment(\.palette) var p
    let icon: String
    let title: String
    let subtitle: String
    let content: () -> Content

    init(icon: String, title: String, subtitle: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(p.selection)
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(p.border, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(p.ink)
                )
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(p.ink)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(p.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
