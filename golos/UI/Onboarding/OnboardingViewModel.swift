import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var modelReady: Bool = false
    @Published var didExplicitlySkipModel: Bool = false
    /// Выбор на шаге автозапуска (nil — ещё не выбрано). Хранится в vm, а не в
    /// шаге, чтобы выбор не сбрасывался при уходе/возврате (шаг пересоздаётся по .id).
    @Published var autolaunchChoice: Bool? = nil
    /// Направление последней навигации: +1 вперёд, -1 назад. Определяет сторону
    /// анимации перехода (иначе «Назад» проигрывается как «Вперёд»).
    @Published var navDirection: Int = 1
    let totalSteps = 7

    var stepTitle: String {
        switch currentStep {
        case 1: return "Привет"
        case 2: return "Микрофон"
        case 3: return "Универсальный доступ"
        case 4: return "Клавиатура"
        case 5: return "Модель"
        case 6: return "Запуск при входе"
        case 7: return "Попробуй"
        default: return ""
        }
    }

    /// Переход на конкретный шаг с правильным направлением анимации.
    func go(to step: Int) {
        guard step >= 1, step <= totalSteps, step != currentStep else { return }
        navDirection = step > currentStep ? 1 : -1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { currentStep = step }
    }

    func next() { go(to: currentStep + 1) }
    func back() { go(to: currentStep - 1) }
}
