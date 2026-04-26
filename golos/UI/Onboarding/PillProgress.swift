import SwiftUI

struct PillProgress: View {
    let total: Int
    let current: Int
    var onTap: (Int) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(height: 5)
                    .onTapGesture { onTap(i + 1) }
            }
        }
    }

    private func color(for i: Int) -> Color {
        if i + 1 < current { return Color.accentColor }
        if i + 1 == current { return Color.accentColor.opacity(0.7) }
        return Color.secondary.opacity(0.18)
    }
}
