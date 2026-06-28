import SwiftUI

struct BannerView: View {
    let text: String
    let action: (String, () -> Void)?
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.system(size: 12))
            Spacer()
            if let (label, fn) = action {
                Button(label, action: fn)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.1))
    }
}

struct SettingsRoot: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        MainWindowView()
            .environmentObject(coordinator)
    }
}
