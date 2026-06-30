import SwiftUI

struct AutolaunchStep: View {
    @ObservedObject var vm: OnboardingViewModel
    let onChoice: (Bool) -> Void

    var body: some View {
        StepLayout(
            iconColors: [.green, .mint],
            icon: "power",
            title: "Запускать вместе с Mac?",
            subtitle: "Чтобы Golos был готов сразу — не запускать его вручную каждый раз."
        ) {
            PermissionScene(granted: vm.autolaunchChoice == true, iconColors: [.green, .mint], icon: "power")
        } content: {
            VStack(spacing: 8) {
                BigChoiceButton(
                    iconName: "checkmark", iconColors: [.green, .mint],
                    title: "Да, запускать автоматически",
                    meta: "Иконка появится в menu bar после входа",
                    isPrimary: true,
                    selected: vm.autolaunchChoice == true
                ) {
                    if #available(macOS 13.0, *) {
                        try? Autolaunch.setEnabled(true)
                    }
                    vm.autolaunchChoice = true
                    onChoice(true)
                }
                BigChoiceButton(
                    iconName: "minus", iconColors: [.gray, .secondary],
                    title: "Спасибо, я сам",
                    meta: "Можно изменить позже в Настройках",
                    isPrimary: false,
                    selected: vm.autolaunchChoice == false
                ) {
                    if #available(macOS 13.0, *) {
                        try? Autolaunch.setEnabled(false)
                    }
                    vm.autolaunchChoice = false
                    onChoice(false)
                }
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
    var selected: Bool = false
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
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.system(size: 16))
                }
            }
            .padding(14)
            .background(selected ? Color.accentColor.opacity(0.14)
                                 : (isPrimary ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.accentColor.opacity(0.6)
                                 : (isPrimary ? Color.accentColor.opacity(0.3) : .clear),
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}
