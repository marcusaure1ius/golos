import SwiftUI

struct AutolaunchStep: View {
    @ObservedObject var vm: OnboardingViewModel
    let onChoice: (Bool) -> Void

    var body: some View {
        StepLayout(
            icon: "power",
            title: "Запускать вместе с Mac?",
            subtitle: "Чтобы Golos был готов сразу — не запускать его вручную каждый раз."
        ) {
            VStack(spacing: 8) {
                ChoiceRow(
                    title: "Да, запускать автоматически",
                    meta: "Иконка появится в menu bar после входа",
                    selected: vm.autolaunchChoice == true
                ) {
                    if #available(macOS 13.0, *) {
                        try? Autolaunch.setEnabled(true)
                    }
                    vm.autolaunchChoice = true
                    onChoice(true)
                }
                ChoiceRow(
                    title: "Спасибо, я сам",
                    meta: "Можно изменить позже в Настройках",
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

struct ChoiceRow: View {
    @Environment(\.palette) var p
    let title: String
    let meta: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(p.ink)
                    Text(meta).font(.system(size: 11)).foregroundStyle(p.muted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(p.ink)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? p.selection : p.card,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(p.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
