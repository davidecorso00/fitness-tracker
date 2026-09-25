import SwiftUI
import SwiftData
import Charts

// MARK: - Corsa: record, distanza, passo, volumi

struct ChartsRunStatsView: View {
    /// Solo corse: le passeggiate stanno nello stesso modello ma non devono
    /// finire nei record di passo e nei km di corsa.
    @Query(filter: #Predicate<RunSession> { $0.activityKind != "walk" },
           sort: \RunSession.date) private var allRunSessions: [RunSession]

    @State private var period: StatPeriod = .threeMonths

    private var earliestDate: Date? { allRunSessions.first?.date }

    private var runsInPeriod: [RunSession] {
        let start = period.startDate(earliest: earliestDate)
        return allRunSessions.filter { $0.date >= start }
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if allRunSessions.isEmpty {
                        ChartCard(title: "Corsa") {
                            VStack(spacing: 10) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 32)).foregroundColor(.muted)
                                Text("Registra una corsa\nper vedere i progressi")
                                    .font(.system(size: 13)).foregroundColor(.muted).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                        } bigValue: { EmptyView() }
                        .padding(.top, 10)
                    } else {
                        recordsCard
                            .padding(.top, 10)
                        PeriodPicker(period: $period)
                        distanceChart
                        paceChart
                        heartRateChart
                        weeklyVolumeChart
                        monthlyVolumeChart
                    }
                }
                .padding(.bottom, 120)
            }
        )
        .navigationTitle("Corsa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
    }

    // ── Record personali (sempre su tutto lo storico) ─────────────────────

    private var recordsCard: some View {
        let longest = allRunSessions.max { $0.distanceMeters < $1.distanceMeters }
        let bestPace = allRunSessions
            .filter { $0.distanceMeters >= 1000 }
            .compactMap { $0.avgPaceSecPerKm }
            .min()

        return HTCard {
            VStack(spacing: 12) {
                SectionLabel(text: "Record corsa")
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    recordItem(icon: "road.lanes",
                               value: String(format: "%.2f km", longest?.distanceKm ?? 0),
                               label: "Corsa più lunga", color: .gymCyan)
                    recordItem(icon: "bolt.fill",
                               value: bestPace.map { paceString($0) + " /km" } ?? "—",
                               label: "Passo migliore", color: .ringGreen)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func recordItem(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.system(size: 11)).foregroundColor(.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Distanza per corsa ────────────────────────────────────────────────

    @ViewBuilder private var distanceChart: some View {
        let runs = runsInPeriod
        if !runs.isEmpty {
            let totalKm = runs.reduce(0) { $0 + $1.distanceKm }
            ChartCard(title: "Distanza") {
                Chart(runs, id: \.persistentModelID) { run in
                    BarMark(x: .value("Data", run.date, unit: .day), y: .value("km", run.distanceKm))
                        .foregroundStyle(Color.gymCyan).cornerRadius(5)
                }
                .standardDateAxis()
                .standardYAxis(suffix: " km")
                .frame(height: 150)
            } bigValue: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f km", totalKm))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.gymCyan)
                    Text("in \(runs.count) corse").font(.system(size: 14)).foregroundColor(.muted)
                }
            }
        }
    }

    // ── Passo medio ───────────────────────────────────────────────────────

    @ViewBuilder private var paceChart: some View {
        let paceData = runsInPeriod.compactMap { run -> (Date, Double)? in
            guard let p = run.avgPaceSecPerKm else { return nil }
            return (run.date, p / 60)
        }
        if !paceData.isEmpty {
            ChartCard(title: "Passo medio") {
                Chart(paceData, id: \.0) { date, paceMin in
                    LineMark(x: .value("Data", date), y: .value("min/km", paceMin))
                        .foregroundStyle(Color.ringGreen).interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Data", date), y: .value("min/km", paceMin))
                        .foregroundStyle(Color.ringGreen).symbolSize(30)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .standardDateAxis()
                .chartYAxis {
                    AxisMarks { v in
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(paceString(d * 60)).font(.system(size: 9)).foregroundStyle(Color.muted)
                            }
                        }
                        AxisGridLine().foregroundStyle(Color.brd)
                    }
                }
                .frame(height: 150)
            } bigValue: {
                if let last = paceData.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(paceString(last.1 * 60))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.ringGreen)
                        Text("/km ultima corsa").font(.system(size: 14)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    // ── Battito medio per corsa ───────────────────────────────────────────

    @ViewBuilder private var heartRateChart: some View {
        let hrData = runsInPeriod.compactMap { run -> (Date, Double, Double)? in
            guard run.avgHeartRate > 0 else { return nil }
            return (run.date, run.avgHeartRate, run.maxHeartRate)
        }
        if !hrData.isEmpty {
            ChartCard(title: "Battito cardiaco") {
                Chart {
                    ForEach(hrData, id: \.0) { date, avg, _ in
                        LineMark(x: .value("Data", date), y: .value("bpm", avg),
                                 series: .value("Serie", "Media"))
                            .foregroundStyle(Color.gymPink).interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Data", date), y: .value("bpm", avg))
                            .foregroundStyle(Color.gymPink).symbolSize(30)
                    }
                    ForEach(hrData, id: \.0) { date, _, maxBpm in
                        LineMark(x: .value("Data", date), y: .value("bpm", maxBpm),
                                 series: .value("Serie", "Max"))
                            .foregroundStyle(Color.ringRed.opacity(0.6))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .standardDateAxis()
                .standardYAxis()
                .frame(height: 150)
            } bigValue: {
                if let last = hrData.last {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(Int(last.1))")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.gymPink)
                            Text("bpm media").font(.system(size: 13)).foregroundColor(.muted)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(Int(last.2))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.ringRed)
                            Text("max").font(.system(size: 13)).foregroundColor(.muted)
                        }
                    }
                }
            }
        }
    }

    // ── Volumi aggregati ──────────────────────────────────────────────────

    private func volume(by component: Calendar.Component) -> [(Date, Double)] {
        let start = period.startDate(earliest: earliestDate)
        var dict = [Date: Double]()
        for r in allRunSessions where r.date >= start {
            guard let s = periodStart(of: r.date, component: component) else { continue }
            dict[s, default: 0] += r.distanceKm
        }
        return dict.sorted { $0.key < $1.key }
    }

    @ViewBuilder private var weeklyVolumeChart: some View {
        let data = volume(by: .weekOfYear)
        if data.count > 1 {
            ChartCard(title: "Km settimanali") {
                Chart(data, id: \.0) { week, km in
                    BarMark(x: .value("Settimana", week, unit: .weekOfYear), y: .value("km", km))
                        .foregroundStyle(Color.gymBlue).cornerRadius(5)
                }
                .standardDateAxis()
                .standardYAxis(suffix: " km")
                .frame(height: 140)
            } bigValue: {
                if let current = data.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f km", current.1))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.gymBlue)
                        Text("questa settimana").font(.system(size: 14)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    @ViewBuilder private var monthlyVolumeChart: some View {
        let data = volume(by: .month)
        if data.count > 1 {
            ChartCard(title: "Km mensili") {
                Chart(data, id: \.0) { month, km in
                    BarMark(x: .value("Mese", month, unit: .month), y: .value("km", km))
                        .foregroundStyle(Color.gymCyan.opacity(0.85)).cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                            .foregroundStyle(Color.muted).font(.system(size: 10))
                    }
                }
                .standardYAxis(suffix: " km")
                .frame(height: 140)
            } bigValue: {
                if let current = data.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f km", current.1))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.gymCyan)
                        Text("questo mese").font(.system(size: 14)).foregroundColor(.muted)
                    }
                }
            }
        }
    }
}
