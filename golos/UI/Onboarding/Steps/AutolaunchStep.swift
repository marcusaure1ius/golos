import SwiftUI

struct AutolaunchStep: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        StepLayout(
            iconColors: [.green, .mint],
            icon: "power",
            title: "Запускать при входе?",
            subtitle: "Чтобы golos был готов сразу — не запускать его вручную каждый раз."
        ) {
            VStack(spacing: 8) {
                BigChoiceButton(
                    iconName: "checkmark", iconColors: [.green, .mint],
                    title: "Да, запускать автоматически",
                    meta: "Иконка появится в menu bar после входа",
                    isPrimary: true
                ) {
                    if #available(macOS 13.0, *) {
                        try? Autolaunch.setEnabled(true)
                    }
                    onChoice(true)
                }
                BigChoiceButton(
                    iconName: "minus", iconColors: [.gray, .secondary],
                    title: "Спасибо, я сам",
                    meta: "Можно изменить позже в Настройках",
                    isPrimary: false
                ) { onChoice(false) }
            }
        }
    }
}

struct BigChoiceButton: View {
    let iconName: String
    let iconColors: [Color]
    let title: String
    let meta: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: iconName).font(.system(size: 14)).foregroundColor(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(meta).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(isPrimary ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isPrimary ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
