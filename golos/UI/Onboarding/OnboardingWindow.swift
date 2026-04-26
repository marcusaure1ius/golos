import SwiftUI

struct OnboardingRoot: View {
    @StateObject var vm = OnboardingViewModel()
    @ObservedObject var settings: AppSettings = .shared
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                PillProgress(total: vm.totalSteps, current: vm.currentStep) { vm.currentStep = $0 }
                HStack {
                    Text(vm.stepTitle).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(vm.currentStep) из \(vm.totalSteps)")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
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
                case 6: AutolaunchStep(onChoice: { _ in vm.next() })
                case 7: DemoStep()
                default: EmptyView()
                }
            }
            .padding(.horizontal, 44).padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack(spacing: 8) {
                Button("‹ Назад") { vm.back() }
                    .buttonStyle(.borderless)
                    .disabled(vm.currentStep == 1)
                Spacer()
                Button("Пропустить") { close() }
                    .buttonStyle(.borderless)
                Button(vm.currentStep == vm.totalSteps ? "Готово" : "Дальше") {
                    if vm.currentStep == vm.totalSteps { close() } else { vm.next() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.currentStep == 5 && !vm.modelReady && !vm.didExplicitlySkipModel)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .frame(width: 580, height: 580)
        .background(.ultraThinMaterial)
    }

    private func close() {
        settings.firstRun = false
        NSApp.keyWindow?.close()
    }
}
