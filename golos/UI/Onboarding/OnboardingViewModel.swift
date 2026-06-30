import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var modelReady: Bool = false
    @Published var didExplicitlySkipModel: Bool = false
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

    func next() { if currentStep < totalSteps { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { currentStep += 1 } } }
    func back() { if currentStep > 1  { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { currentStep -= 1 } } }
}
