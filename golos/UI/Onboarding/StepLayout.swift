import SwiftUI

struct StepLayout<Content: View, Scene: View>: View {
    let iconColors: [Color]
    let icon: String
    let title: String
    let subtitle: String
    let scene: () -> Scene
    let content: () -> Content

    init(iconColors: [Color], icon: String, title: String, subtitle: String,
         @ViewBuilder scene: @escaping () -> Scene,
         @ViewBuilder content: @escaping () -> Content) {
        self.iconColors = iconColors
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.scene = scene
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            // Левая панель: иконка, заголовок, копирайт, контент/действие
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundColor(.white))
                    .shadow(color: iconColors.first?.opacity(0.4) ?? .clear, radius: 14, y: 6)
                Text(title).font(.system(size: 23, weight: .bold)).tracking(-0.4)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 330, alignment: .leading)
                content()
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)

            // Правая панель: «сцена»
            ZStack { scene() }
                .frame(width: 280)
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension StepLayout where Scene == EmptyView {
    init(iconColors: [Color], icon: String, title: String, subtitle: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(iconColors: iconColors, icon: icon, title: title, subtitle: subtitle,
                  scene: { EmptyView() }, content: content)
    }
}

/// Маленький status pill — серая/зелёная капсула со статусом permission.
struct PermStatusPill: View {
    let granted: Bool
    let pendingText: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().frame(width: 7, height: 7)
            Text(granted ? "Разрешено" : pendingText)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundColor(color)
    }

    private var color: Color { granted ? .green : .orange }
}

/// Карточка с цветным иконом + label/meta + slot справа (status / progress).
struct PermCard<Trailing: View>: View {
    let iconColors: [Color]
    let iconName: String
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: iconName).foregroundColor(.white).font(.system(size: 14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
