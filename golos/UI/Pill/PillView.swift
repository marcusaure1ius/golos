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
}

struct PillView: View {
    @ObservedObject var vm: PillViewModel
    @State private var spinAngle: Double = 0

    var body: some View {
        HStack(spacing: 14) {
            indicator
            waveform
            hint
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [
                Color.white.opacity(isError ? 0.12 : 0.22),
                Color.white.opacity(isError ? 0.04 : 0.08),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(isError ? 0.30 : 0.22), lineWidth: 1))
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 12)
        .frame(width: 240, height: 48)
    }

    private var isError: Bool {
        if case .error = vm.state { return true }
        return false
    }

    @ViewBuilder
    private var indicator: some View {
        ZStack {
            Image(systemName: "mic.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(spinAngle))
                .onAppear { startSpin() }
                .onChange(of: vm.state) { _, _ in startSpin() }
        }
    }

    private func startSpin() {
        let speed: Double = (vm.state == .transcribing) ? 0.6 : 1.4
        spinAngle = 0
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            spinAngle = 360
        }
    }

    @ViewBuilder
    private var waveform: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(vm.history.enumerated()), id: \.offset) { idx, v in
                Capsule()
                    .fill(Color.white.opacity(0.3 + 0.7 * Double(idx) / Double(vm.history.count - 1)))
                    .frame(width: 2, height: max(2, CGFloat(v) * 28))
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private var hint: some View {
        Text(hintText)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(isError ? 0.95 : 0.85))
            .lineLimit(1)
    }

    private var hintText: String {
        switch vm.state {
        case .recording(.ptt): return L10n.pillListening
        case .recording(.toggle): return L10n.pillToggleStop
        case .transcribing: return L10n.pillTranscribing
        case .error(let m): return m.isEmpty ? L10n.pillError : m
        }
    }
}
