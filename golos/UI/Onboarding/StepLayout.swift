import SwiftUI

struct StepLayout<Content: View>: View {
    let iconColors: [Color]
    let icon: String
    let title: String
    let subtitle: String
    let content: () -> Content

    init(iconColors: [Color], icon: String, title: String, subtitle: String,
         @ViewBuilder content: @escaping () -> Content) {
        self.iconColors = iconColors
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(Image(systemName: icon).font(.system(size: 32, weight: .semibold)).foregroundColor(.white))
                .shadow(color: iconColors.first?.opacity(0.4) ?? .clear, radius: 18, y: 8)
            Text(title).font(.system(size: 26, weight: .bold)).tracking(-0.5)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).frame(maxWidth: 460, alignment: .leading)
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
