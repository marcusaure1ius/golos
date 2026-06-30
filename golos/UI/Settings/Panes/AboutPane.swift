import SwiftUI
import AppKit

struct AboutPane: View {
    @Environment(\.palette) var p
    @State private var hoverGithub = false
    @State private var hoverDocs = false
    @State private var hoverBug = false

    // Высоты баров декоративной вейвформы из мокапа (34 бара, 5..32px)
    private let waveHeights: [CGFloat] = [
        7, 11, 17, 23, 16, 9, 6, 10, 18, 26, 32, 22, 13, 8, 12, 20, 28,
        19, 11, 7, 9, 15, 23, 30, 21, 12, 8, 5, 9, 16, 22, 14, 8, 6
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Иконка приложения: 98×98 графитовый сквиркл, 4 белых вертикальных бара
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: 0x34343c), location: 0),
                                .init(color: Color(hex: 0x17171b), location: 0.68),
                                .init(color: Color(hex: 0x0c0c0f), location: 1),
                            ],
                            // CSS 158° → SwiftUI startPoint / endPoint
                            startPoint: UnitPoint(x: 0.31, y: 0.04),
                            endPoint: UnitPoint(x: 0.69, y: 0.96)
                        )
                    )
                HStack(spacing: 7) {
                    ForEach([15, 38, 54, 26].indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 7, height: [15, 38, 54, 26][i])
                    }
                }
            }
            .frame(width: 98, height: 98)

            // Название
            Text("Golos")
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.68) // letter-spacing: -.02em × 34pt
                .foregroundStyle(p.ink)
                .padding(.top, 26)

            // Чип версии
            Text("Версия \(Bundle.main.shortVersion)")
                .font(.system(size: 12.5))
                .foregroundStyle(p.muted)
                .padding(.vertical, 4)
                .padding(.horizontal, 13)
                .overlay(Capsule().strokeBorder(p.border, lineWidth: 1))
                .padding(.top, 16)

            // Подзаголовок
            Text("Локальная диктовка для macOS")
                .font(.system(size: 14.5))
                .foregroundStyle(p.muted)
                .padding(.top, 20)

            // Декоративная вейвформа
            HStack(spacing: 3) {
                ForEach(Array(waveHeights.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(p.border)
                        .frame(width: 3, height: h)
                }
            }
            .frame(height: 38)
            .mask {
                // Горизонтальное затухание: прозрачно по ~16% с каждого края
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.16),
                        .init(color: .black, location: 0.84),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .padding(.top, 32)

            // Ссылки: GitHub, Документация, Сообщить об ошибке
            // Без рамки/фона — только цвет muted→ink при наведении.
            HStack(spacing: 24) {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/")!)
                } label: {
                    // GitHub не имеет нативного SF Symbol — используем символ кода
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(hoverGithub ? p.ink : p.muted)
                        .font(.system(size: 13.5))
                }
                .buttonStyle(.plain)
                .onHover { hoverGithub = $0 }

                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/")!)
                } label: {
                    Label("Документация", systemImage: "book")
                        .foregroundStyle(hoverDocs ? p.ink : p.muted)
                        .font(.system(size: 13.5))
                }
                .buttonStyle(.plain)
                .onHover { hoverDocs = $0 }

                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/")!)
                } label: {
                    Label("Сообщить об ошибке", systemImage: "exclamationmark.bubble")
                        .foregroundStyle(hoverBug ? p.ink : p.muted)
                        .font(.system(size: 13.5))
                }
                .buttonStyle(.plain)
                .onHover { hoverBug = $0 }
            }
            .padding(.top, 30)

            // Копирайт
            Text("© 2026 · Golos")
                .font(.system(size: 12))
                .foregroundStyle(p.muted2)
                .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
}
