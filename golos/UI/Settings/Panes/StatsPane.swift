import SwiftUI
import Charts

// MARK: - Диапазон диаграммы

private enum StatsRange { case days, weeks }

// MARK: - Точка столбчатой диаграммы

private struct ChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

// MARK: - Панель «Статистика»

struct StatsPane: View {
    @Environment(\.palette) var p

    @State private var buckets: [DayBucket] = []
    @State private var range: StatsRange = .days
    @State private var hovered: ChartPoint.ID?

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f
    }()

    // MARK: Вычисляемые

    private var totals: (dictations: Int, words: Int) { StatsAggregator.totals(buckets) }

    private var last7Days: [DaySeries] {
        StatsAggregator.lastDays(buckets, count: 7, calendar: .current, now: Date())
    }

    private var points: [ChartPoint] {
        switch range {
        case .days:
            return last7Days.map {
                ChartPoint(label: Self.dayFmt.string(from: $0.date), count: $0.dictations)
            }
        case .weeks:
            return StatsAggregator.lastWeeks(buckets, count: 7, calendar: .current, now: Date()).map {
                ChartPoint(label: Self.dayFmt.string(from: $0.weekStart), count: $0.dictations)
            }
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Статистика")
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(p.ink)

            topCards
                .frame(height: 132)

            chartCard
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await StatsStore.shared.seedIfNeeded(from: HistoryStore.shared.all())
            buckets = await StatsStore.shared.snapshot()
        }
    }

    // MARK: Верхние карточки

    private var topCards: some View {
        HStack(spacing: 16) {
            statCard(title: "Всего диктовок",
                     value: totals.dictations,
                     trend: last7Days.map { Double($0.dictations) })
            statCard(title: "Всего слов",
                     value: totals.words,
                     trend: last7Days.map { Double($0.words) })
        }
    }

    private func statCard(title: String, value: Int, trend: [Double]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(p.muted)
                Text(value.formatted(.number))
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(p.ink)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            sparkline(trend)
                .frame(width: 92, height: 34)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.border, lineWidth: 1)
        )
    }

    private func sparkline(_ values: [Double]) -> some View {
        Chart(Array(values.enumerated()), id: \.offset) { idx, v in
            LineMark(x: .value("i", idx), y: .value("v", v))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(p.accent.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 1.8))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(values.max() ?? 1, 1))
    }

    // MARK: Карточка диаграммы

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Динамика диктовок")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.16)
                    .foregroundStyle(p.ink)
                Spacer()
                rangeToggle
            }
            barChart
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(p.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(p.border, lineWidth: 1)
        )
    }

    private var barChart: some View {
        Chart(points) { pt in
            BarMark(
                x: .value("Дата", pt.label),
                y: .value("Диктовки", pt.count),
                width: .fixed(24)
            )
            .cornerRadius(4)
            .foregroundStyle(p.accent.opacity(hovered == nil || hovered == pt.id ? 1 : 0.35))
            .annotation(position: .top, alignment: .center, spacing: 6) {
                if hovered == pt.id {
                    VStack(spacing: 1) {
                        Text(pt.label)
                            .font(.system(size: 11))
                            .foregroundStyle(p.muted)
                        Text("\(pt.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(p.ink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(p.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(p.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(p.borderSoft)
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 11))
                    .foregroundStyle(p.muted)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        guard case .active(let loc) = phase, let plot = proxy.plotFrame else {
                            hovered = nil
                            return
                        }
                        let x = loc.x - geo[plot].origin.x
                        if let label: String = proxy.value(atX: x) {
                            hovered = points.first { $0.label == label }?.id
                        } else {
                            hovered = nil
                        }
                    }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Тумблер Дни/Недели

    private var rangeToggle: some View {
        HStack(spacing: 2) {
            toggleSegment("Дни", .days)
            toggleSegment("Недели", .weeks)
        }
        .padding(2)
        .background(p.selection)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func toggleSegment(_ title: String, _ value: StatsRange) -> some View {
        let active = range == value
        return Text(title)
            .font(.system(size: 12.5, weight: active ? .medium : .regular))
            .foregroundStyle(active ? p.ink : p.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(active ? p.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { range = value }
    }
}
