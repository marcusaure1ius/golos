import SwiftUI

struct HistoryPane: View {
    @ObservedObject var settings: AppSettings = .shared

    var body: some View {
        Group {
            if settings.historyEnabled {
                List {
                    ContentUnavailableView("Пока нет записей", systemImage: "clock", description: Text("Подиктуй что-нибудь, и записи появятся здесь."))
                }
            } else {
                ContentUnavailableView {
                    Label("История выключена", systemImage: "clock")
                } description: {
                    Text("Включи «Сохранять историю транскриптов» в разделе Приватность.")
                } actions: {
                    Button("Открыть Приватность") {}
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("История")
    }
}
