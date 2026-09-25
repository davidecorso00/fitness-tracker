import SwiftUI
import SwiftData
import Charts

// MARK: - Corpo: peso, trend, bilancio calorico, grasso stimato

struct ChartsBodyView: View {
    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]
    @Query private var allProfiles: [UserProfile]
    @Query private var allLimits: [AppLimits]

    @State private var period: StatPeriod = .threeMonths

    // Cache O(1) per giorno
    @State private var kcalByDay: [String: Double] = [:]
    @State private var sportByDay: [String: SportKcal] = [:]
    @State private var logByDay: [String: DayLog] = [:]
    @State private var sortedWeights: [(String, Double)] = []

    private var dataFingerprint: Int {
        allEntries.count &* 31 &+ allLogs.count &* 37 &+ allSports.count &* 41
    }

    private var earliestDate: Date? {
        guard let first = allLogs.first?.dateKey else { return nil }
        return dateFromKey(first)
    }

    private var dates: [Date] { period.dates(earliest: earliestDate) }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PeriodPicker(period: $period)
                        .padding(.top, 10)

                    weightChart
                    calorieBalanceChart
                    fatLossChart
                }
                .padding(.bottom, 120)
            }
        )
        .navigationTitle("Corpo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .onAppear { rebuildDicts() }
        .onChange(of: dataFingerprint) { rebuildDicts() }
    }

    // ── Peso + trend smussato ─────────────────────────────────────────────

    @ViewBuilder private var weightChart: some View {
        let start = period.startDate(earliest: earliestDate)
        let raw: [(Date, Double)] = sortedWeights.compactMap { key, w in
            guard let d = dateFromKey(key), d >= start else { return nil }
            return (d, w)
        }
        let trend = movingAverage(raw, window: 7)

        if raw.isEmpty {
            emptyCard(title: "Peso", message: "Registra il peso per vedere il trend")
        } else {
            ChartCard(title: "Peso · trend smussato") {
                Chart {
                    ForEach(raw, id: \.0) { date, w in
                        PointMark(x: .value("Data", date), y: .value("kg", w))
                            .foregroundStyle(Color.gymGreen.opacity(0.35)).symbolSize(22)
                    }
                    ForEach(trend, id: \.0) { date, w in
                        LineMark(x: .value("Data", date), y: .value("Trend", w))
                            .foregroundStyle(Color.gymGreen)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                    if let target = allLimits.first?.targetWeight, target > 0 {
                        RuleMark(y: .value("Obiettivo", target))
                            .foregroundStyle(Color.gymOrange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("obiettivo \(target.formatted1)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.gymOrange)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .standardDateAxis()
                .standardYAxis()
                .frame(height: 180)
            } bigValue: {
                if let last = trend.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(last.1.formatted1)
                            .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.txt)
                        Text("kg trend").font(.system(size: 14)).foregroundColor(.muted)
                        if trend.count > 1 {
                            let delta = last.1 - trend[0].1
                            Text(delta >= 0 ? "+\(delta.formatted1)" : delta.formatted1)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(delta <= 0 ? .gymGreen : .gymOrange)
                        }
                    }
                }
            }
        }
    }

    // ── Bilancio calorico ─────────────────────────────────────────────────

    @ViewBuilder private var calorieBalanceChart: some View {
        let daily: [(date: Date, net: Double)] = dates.compactMap { d in
            let eaten = kcalByDay[d.dateKey] ?? 0
            guard eaten > 0, let burn = dailyBurn(for: d) else { return nil }
            return (d, eaten - burn)
        }
        if daily.isEmpty {
            EmptyView()
        } else {
            var cumulative = 0.0
            let cumData: [(Date, Double)] = daily.map { cumulative += $0.net; return ($0.date, cumulative) }
            let totalNet = cumData.last?.1 ?? 0

            ChartCard(title: "Bilancio calorico") {
                Chart {
                    ForEach(daily, id: \.date) { item in
                        BarMark(x: .value("Data", item.date, unit: .day), y: .value("kcal", item.net))
                            .foregroundStyle(item.net <= 0 ? Color.gymGreen : Color.gymOrange)
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.muted.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                }
                .standardDateAxis()
                .standardYAxis()
                .frame(height: 170)
            } bigValue: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(totalNet <= 0
                         ? "-\(Int(abs(totalNet)).stepsFormatted)"
                         : "+\(Int(totalNet).stepsFormatted)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(totalNet <= 0 ? .gymGreen : .gymOrange)
                    Text("kcal cumulative nel periodo").font(.system(size: 13)).foregroundColor(.muted)
                }
            }
        }
    }

    // ── Grasso perso (stima) ──────────────────────────────────────────────

    @ViewBuilder private var fatLossChart: some View {
        let data = fatLossData()
        if !data.isEmpty {
            ChartCard(title: "Grasso perso (stima)") {
                Chart(data, id: \.date) { item in
                    AreaMark(x: .value("Data", item.date), y: .value("kg", item.kg))
                        .foregroundStyle(item.kg >= 0
                            ? Color.gymGreen.opacity(0.2).gradient
                            : Color.gymOrange.opacity(0.2).gradient)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Data", item.date), y: .value("kg", item.kg))
                        .foregroundStyle(item.kg >= 0 ? Color.gymGreen : Color.gymOrange)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.muted.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                }
                .standardDateAxis()
                .standardYAxis(suffix: "kg")
                .frame(height: 170)
            } bigValue: {
                if let last = data.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(last.kg >= 0
                             ? "-\(String(format: "%.2f", last.kg)) kg"
                             : "+\(String(format: "%.2f", abs(last.kg))) kg")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(last.kg >= 0 ? .gymGreen : .gymOrange)
                        Text("grasso cumulativo").font(.system(size: 13)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private func emptyCard(title: String, message: String) -> some View {
        ChartCard(title: title) {
            Text(message)
                .font(.system(size: 13)).foregroundColor(.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 20)
        } bigValue: { EmptyView() }
    }

    /// Ultimo peso registrato fino a quel giorno; per i giorni prima della prima
    /// pesata si usa la prima disponibile.
    private func weight(for date: Date) -> Double? {
        sortedWeights.last { $0.0 <= date.dateKey }?.1 ?? sortedWeights.first?.1
    }

    private func dailyBurn(for date: Date) -> Double? {
        totalDailyBurn(log: logByDay[date.dateKey],
                       sport: sportByDay[date.dateKey] ?? SportKcal(),
                       profile: allProfiles.first,
                       weightKg: weight(for: date),
                       on: date)
    }

    private func fatLossData() -> [(date: Date, kg: Double)] {
        let hasSomeData = dates.contains { (kcalByDay[$0.dateKey] ?? 0) > 0 || (logByDay[$0.dateKey]?.steps ?? 0) > 0 }
        guard hasSomeData else { return [] }
        var cumulative = 0.0
        var result: [(Date, Double)] = []
        for date in dates {
            // Solo i giorni con il cibo registrato, come nel bilancio calorico e nei
            // Risultati: un giorno senza pasti conterebbe tutto il consumo come deficit.
            let eaten = kcalByDay[date.dateKey] ?? 0
            guard eaten > 0, let burn = dailyBurn(for: date) else { continue }
            let deficit = burn - eaten
            cumulative += deficit / 7700.0
            result.append((date, cumulative))
        }
        return result
    }

    private func rebuildDicts() {
        var kd = [String: Double]()
        for e in allEntries { kd[e.dayKey, default: 0] += e.kcalSnapshot }
        let sd = allSports.sportKcalByDay()
        var ld = [String: DayLog]()
        var sw = [(String, Double)]()
        for log in allLogs {   // sorted ascending
            ld[log.dateKey] = log
            if let w = log.weight { sw.append((log.dateKey, w)) }
        }
        kcalByDay = kd; sportByDay = sd; logByDay = ld; sortedWeights = sw
    }
}

// MARK: - Key → Date

private let keyParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

func dateFromKey(_ key: String) -> Date? { keyParser.date(from: key) }
