import SwiftUI

struct OnboardingRoot: View {
    @StateObject var vm = OnboardingViewModel()
    @ObservedObject var settings: AppSettings = .shared
    @StateObject private var system = SystemAppearance()
    @State private var showSkipConfirm = false

    private var effectiveScheme: ColorScheme {
        switch settings.themeMode {
        case .auto:  return system.scheme
        case .light: return .light
        case .dark:  return .dark
        }
    }

    private var skipMessage: String {
        switch vm.currentStep {
        case 5: return "Модель не выбрана — диктовка не заработает до установки модели."
        case 2: return "Без доступа к микрофону диктовка не заработает."
        case 3: return "Без Универсального доступа вставка текста будет ограничена."
        case 4: return "Без Input Monitoring горячие клавиши не будут работать."
        default: return "Ты сможешь вернуться к настройке позже через Настройки."
        }
    }

    var body: some View {
        let p = Palette.of(effectiveScheme)
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                PillProgress(total: vm.totalSteps, current: vm.currentStep) { vm.go(to: $0) }
                HStack {
                    Text(vm.stepTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(p.ink)
                    Spacer()
                    Text("\(vm.currentStep) из \(vm.totalSteps)")
                        .font(.system(size: 11))
                        .foregroundStyle(p.muted)
                }
            }
            .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 12)

            Group {
                switch vm.currentStep {
                case 1: HelloStep()
                case 2: MicrophoneStep()
                case 3: AccessibilityStep()
                case 4: InputMonitoringStep()
                case 5: ModelStep(vm: vm)
                case 6: AutolaunchStep(vm: vm, onChoice: { _ in vm.next() })
                case 7: DemoStep(vm: vm)
                default: EmptyView()
                }
            }
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 44).padding(.vertical, 12)
            .id(vm.currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: vm.navDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: vm.navDirection >= 0 ? .leading : .trailing).combined(with: .opacity)))

            Divider()
            HStack(spacing: 8) {
                Button("‹ Назад") { vm.back() }
                    .buttonStyle(GhostButton())
                    .disabled(vm.currentStep == 1)
                    .opacity(vm.currentStep == 1 ? 0.4 : 1)
                Spacer()
                Button("Пропустить") { showSkipConfirm = true }
                    .buttonStyle(GhostButton())
                    .alert("Пропустить настройку?", isPresented: $showSkipConfirm) {
                        Button("Продолжить настройку", role: .cancel) {}
                        Button("Закрыть и настроить позже", role: .destructive) {
                            settings.onboardingSkipped = true
                            vm.didExplicitlySkipModel = true
                            close()
                        }
                    } message: {
                        Text(skipMessage)
                    }
                Button(vm.currentStep == vm.totalSteps ? "Готово" : "Дальше") {
                    if vm.currentStep == vm.totalSteps {
                        settings.onboardingCompleted = true
                        close()
                    } else {
                        vm.next()
                    }
                }
                .buttonStyle(PrimaryButton())
                .disabled(vm.currentStep == 5 && !vm.modelReady && !vm.didExplicitlySkipModel)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .frame(width: 760, height: 520)
        .background(p.bg)
        .environment(\.palette, p)
        .preferredColorScheme(effectiveScheme)
    }

    private func close() {
        if vm.currentStep == vm.totalSteps || settings.onboardingSkipped {
            settings.firstRun = false
        }
        NSApp.keyWindow?.close()
    }
}
