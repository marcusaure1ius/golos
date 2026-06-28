import SwiftUI

/// Состояние, которое pill отображает.
enum PillState: Equatable {
    case recording(mode: DictationCoordinator.Mode)
    case transcribing
    case error(message: String)
}

@MainActor
final class PillViewModel: ObservableObject {
    @Published var state: PillState
    /// История RMS — кольцевой буфер, длина 50, новые значения справа.
    @Published private(set) var history: [Float] = Array(repeating: 0, count: 50)

    init(state: PillState) { self.state = state }

    func appendLevel(_ rms: Float) {
        var h = history
        h.removeFirst()
        h.append(rms)
        history = h
    }

    /// Сбросить волну амплитуд — при старте новой записи, чтобы новая
    /// сессия не продолжала предыдущую.
    func resetHistory() {
        history = Array(repeating: 0, count: 50)
    }
}

struct PillView: View {
    @ObservedObject var vm: PillViewModel
    @State private var spinAngle: Double = 0
    @State private var pulseScale: CGFloat = 1
    @State private var pulseOpacity: Double = 0.7
    @State private var dotPhase: Int = 0

    private static let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        // Внешний фрейм с запасом — чтобы .shadow() не обрезался границами NSPanel.
        ZStack {
            HStack(spacing: 12) {
                indicator
                center
                hint
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: isError
                        ? [Color(red: 0.50, green: 0.12, blue: 0.12).opacity(0.55),
                           Color(red: 0.30, green: 0.06, blue: 0.06).opacity(0.65)]
                        : [Color.black.opacity(0.40),
                           Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isError ? 0.65 : 0.60),  // яркий блик сверху
                            Color.white.opacity(isError ? 0.18 : 0.14),  // гаснет книзу
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)  // деликатная тень
            .frame(width: 340, height: 52)
        }
        .frame(width: 400, height: 96)
    }

    // MARK: - State helpers

    private var isError: Bool {
        if case .error = vm.state { return true }
        return false
    }

    private var isToggle: Bool {
        if case .recording(.toggle) = vm.state { return true }
        return false
    }

    private var isTranscribing: Bool {
        vm.state == .transcribing
    }

    // MARK: - Indicator (mic / error icon + halo)

    @ViewBuilder
    private var indicator: some View {
        ZStack {
            // Иконка
            Image(systemName: isError ? "exclamationmark.circle.fill" : "mic.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isError ? Color(red: 1.0, green: 0.8, blue: 0.8) : .white)

            if !isError {
                // Halo: 3/4 окружности, крутится; в transcribing — быстрее.
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                    .rotationEffect(.degrees(spinAngle))
                    .onAppear { startSpin() }
                    .onChange(of: vm.state) { _, _ in startSpin() }

                // Toggle-режим: дополнительное "дышащее" кольцо вокруг halo.
                if isToggle {
                    Circle()
                        .stroke(Color.white.opacity(pulseOpacity), lineWidth: 1.5)
                        .scaleEffect(pulseScale)
                        .onAppear { startPulse() }
                }
            }
        }
        .frame(width: 22, height: 22)
    }

    private func startSpin() {
        let speed: Double = isTranscribing ? 0.6 : 1.4
        spinAngle = 0
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            spinAngle = 360
        }
    }

    private func startPulse() {
        pulseScale = 1
        pulseOpacity = 0.7
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.18
            pulseOpacity = 0.35
        }
    }

    // MARK: - Center: waveform / dots / error line

    @ViewBuilder
    private var center: some View {
        switch vm.state {
        case .recording:
            waveform
        case .transcribing:
            dots
        case .error:
            errorLine
        }
    }

    /// 50 баров RMS истории. Контейнер 130pt, бары 1.5pt + gap 1pt = ~125pt.
    /// Высота: sqrt(rms) — даёт больше визуальной динамики для тихих микрофонов
    /// (типичный input даёт RMS 0.01-0.05, линейная шкала превращала бы в 1px точки).
    @ViewBuilder
    private var waveform: some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(Array(vm.history.enumerated()), id: \.offset) { idx, v in
                Capsule()
                    .fill(Color.white.opacity(0.3 + 0.7 * Double(idx) / Double(vm.history.count - 1)))
                    .frame(width: 1.5, height: barHeight(rms: v))
            }
        }
        .frame(width: 130, height: 28)
        .clipped()
    }

    private func barHeight(rms: Float) -> CGFloat {
        // sqrt-scale, потолок = диаметр halo вокруг микрофона (22pt), чтобы громкая
        // речь визуально доходила до уровня крутящегося кружка.
        // rms=0.02 → ~11px, rms=0.05 → ~18px, rms=0.08+ → упор в 22px.
        let scaled = sqrt(max(0, Double(rms)))
        return max(1.5, min(22, CGFloat(scaled) * 80))
    }

    /// 3 пульсирующие точки для transcribing.
    @ViewBuilder
    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotPhase == i ? 1.1 : 0.8)
                    .opacity(dotPhase == i ? 1.0 : 0.3)
            }
        }
        .frame(width: 130, height: 28)
        .onReceive(Self.dotTimer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }

    @ViewBuilder
    private var errorLine: some View {
        Text(L10n.pillError)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(red: 1.0, green: 0.67, blue: 0.67))
            .frame(width: 130, height: 28)
    }

    // MARK: - Hint

    @ViewBuilder
    private var hint: some View {
        Text(hintText)
            .font(.system(size: 11))
            .foregroundColor(hintColor)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hintText: String {
        switch vm.state {
        case .recording(.ptt): return L10n.pillListening
        case .recording(.toggle): return L10n.pillToggleStop
        case .transcribing: return L10n.pillTranscribing
        case .error(let m): return m.isEmpty ? L10n.pillError : m
        }
    }

    private var hintColor: Color {
        switch vm.state {
        case .recording(.toggle): return Color(red: 1.0, green: 0.82, blue: 0.48)  // тёплый жёлтый
        case .error: return Color(red: 1.0, green: 0.67, blue: 0.67)
        default: return .white.opacity(0.85)
        }
    }
}
