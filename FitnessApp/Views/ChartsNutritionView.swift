import SwiftUI
import SwiftData
import Charts

// MARK: - Nutrizione: calorie, macro, aderenza proteine, acqua

struct ChartsNutritionView: View {
    @Query private var allEntries: [FoodEntry]
    @Query private var allLimits: [AppLimits]
    @Query(sort: \TargetHistory.effectiveDate) private var allTargetHistory: [TargetHistory]
    @Query private var allWaterEntries: [WaterEntry]

    @State private var period: StatPeriod = .month

    private struct DayMacros {
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }
    @State private var macrosByDay: [String: DayMacros] = [:]
    @State private var waterByDay: [String: Double] = [:]

    private var dataFingerprint: Int {
        allEntries.count &* 31 &+ allWaterEntries.count &* 43
    }

    private var earliestDate: Date? {
        allEntries.map(\.date).min()
    }

    private var dates: [Date] { period.dates(earliest: earliestDate) }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PeriodPicker(period: $period)
                        .padding(.top, 10)

                    kcalChart
                    macroCompositionChart
                    proteinAdherenceChart
                    waterChart
                }
                .padding(.bottom, 120)
            }
        )
        .navigationTitle("Nutrizione")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .onAppear { rebuildDicts() }
        .onChange(of: dataFingerprint) { rebuildDicts() }
    }

    private func targets(for date: Date) -> TargetHistory? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return allTargetHistory.last {
            Calendar.current.startOfDay(for: $0.effectiveDate) <= dayStart
        } ?? allTargetHistory.first
    }

    // ── Calorie ───────────────────────────────────────────────────────────

    @ViewBuilder private var kcalChart: some View {
        let kcalData = dates.map { (date: $0, kcal: macrosByDay[$0.dateKey]?.kcal ?? 0) }
        let todayTarget = targets(for: Date())?.kcalTarget ?? allLimits.first?.kcalTarget ?? 2255
        let daysWith = kcalData.filter { $0.kcal > 0 }
        let avg = daysWith.isEmpty ? 0.0 : daysWith.map(\.kcal).reduce(0, +) / Double(daysWith.count)

        ChartCard(title: "Calorie") {
            Chart {
                ForEach(kcalData, id: \.date) { item in
                    let dayTarget = targets(for: item.date)?.kcalTarget ?? todayTarget
                    BarMark(x: .value("Data", item.date, unit: .day), y: .value("kcal", item.kcal))
                        .foregroundStyle(item.kcal > dayTarget ? Color.gymOrange : Color.ringRed)
                        .cornerRadius(4)
                }
                if avg > 0 {
                    RuleMark(y: .value("Media", avg))
                        .foregroundStyle(Color.gymOrange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("media \(Int(avg))")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.gymOrange)
                        }
                }
            }
            .standardDateAxis()
            .standardYAxis()
            .frame(height: 160)
        } bigValue: {
            if let today = kcalData.last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(today.kcal))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(today.kcal > todayTarget ? .gymOrange : .txt)
                    Text("/ \(Int(todayTarget)) kcal").font(.system(size: 14)).foregroundColor(.muted)
                    if avg > 0 {
                        Spacer()
                        Text("media \(Int(avg))").font(.system(size: 13)).foregroundColor(.gymOrange)
                    }
                }
            }
        }
    }

    // ── Composizione macro ────────────────────────────────────────────────

    private struct MacroSlice: Identifiable {
        let id = UUID()
        let date: Date
        let name: String
        let grams: Double
    }

    @ViewBuilder private var macroCompositionChart: some View {
        let slices: [MacroSlice] = dates.flatMap { d -> [MacroSlice] in
            guard let m = macrosByDay[d.dateKey], m.kcal > 0 else { return [] }
            return [
                MacroSlice(date: d, name: "Proteine", grams: m.protein),
                MacroSlice(date: d, name: "Carboidrati", grams: m.carbs),
                MacroSlice(date: d, name: "Grassi", grams: m.fat),
            ]
        }
        if !slices.isEmpty {
            ChartCard(title: "Composizione macro") {
                Chart(slices) { slice in
                    BarMark(x: .value("Data", slice.date, unit: .day),
                            y: .value("g", slice.grams))
                        .foregroundStyle(by: .value("Macro", slice.name))
                        .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    "Proteine": Color.ringGreen,
                    "Carboidrati": Color.gymBlue,
                    "Grassi": Color.gymOrange,
                ])
                .chartLegend(position: .bottom, spacing: 8) {
                    HStack(spacing: 12) {
                        legendDot(color: .ringGreen, label: "Proteine")
                        legendDot(color: .gymBlue, label: "Carboidrati")
                        legendDot(color: .gymOrange, label: "Grassi")
                    }
                }
                .standardDateAxis()
                .standardYAxis(suffix: "g")
                .frame(height: 170)
            } bigValue: {
                let totP = slices.filter { $0.name == "Proteine" }.reduce(0) { $0 + $1.grams }
                let totC = slices.filter { $0.name == "Carboidrati" }.reduce(0) { $0 + $1.grams }
                let totF = slices.filter { $0.name == "Grassi" }.reduce(0) { $0 + $1.grams }
                let tot = max(totP + totC + totF, 1)
                HStack(spacing: 10) {
                    macroPct(label: "P", pct: totP / tot, color: .ringGreen)
                    macroPct(label: "C", pct: totC / tot, color: .gymBlue)
                    macroPct(label: "G", pct: totF / tot, color: .gymOrange)
                }
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 10)).foregroundColor(.muted)
        }
    }

    private func macroPct(label: String, pct: Double, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(color)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.txt)
        }
    }

    // ── Aderenza proteine ─────────────────────────────────────────────────

    @ViewBuilder private var proteinAdherenceChart: some View {
        let data: [(date: Date, p: Double, target: Double)] = dates.compactMap { d in
            guard let m = macrosByDay[d.dateKey], m.kcal > 0 else { return nil }
            let t = targets(for: d)?.proteinTarget ?? allLimits.first?.proteinTarget ?? 200
            return (d, m.protein, t)
        }
        if !data.isEmpty {
            let hit = data.filter { $0.p >= $0.target }.count
            let pct = Int(Double(hit) / Double(data.count) * 100)
            let todayTarget = targets(for: Date())?.proteinTarget ?? allLimits.first?.proteinTarget ?? 200

            ChartCard(title: "Aderenza proteine") {
                Chart {
                    ForEach(data, id: \.date) { item in
                        BarMark(x: .value("Data", item.date, unit: .day), y: .value("g", item.p))
                            .foregroundStyle(item.p >= item.target ? Color.ringGreen : Color.ringGreen.opacity(0.35))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Target", todayTarget))
                        .foregroundStyle(Color.ringGreen.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("target \(Int(todayTarget))g")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.ringGreen)
                        }
                }
                .standardDateAxis()
                .standardYAxis(suffix: "g")
                .frame(height: 150)
            } bigValue: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(pct)%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(pct >= 80 ? .ringGreen : (pct >= 50 ? .gymOrange : .gymPink))
                    Text("giorni a target (\(hit)/\(data.count))")
                        .font(.system(size: 13)).foregroundColor(.muted)
                }
            }
        }
    }

    // ── Acqua ─────────────────────────────────────────────────────────────

    @ViewBuilder private var waterChart: some View {
        let waterData = dates.map { (date: $0, liters: waterByDay[$0.dateKey] ?? 0) }
        let daysWith = waterData.filter { $0.liters > 0 }
        if !daysWith.isEmpty {
            let avg = daysWith.map(\.liters).reduce(0, +) / Double(daysWith.count)
            let target = allLimits.first?.waterTarget ?? 2.0
            let waterBlue = Color(hex: "5AC8FA")

            ChartCard(title: "Acqua") {
                Chart {
                    ForEach(waterData, id: \.date) { item in
                        BarMark(x: .value("Data", item.date, unit: .day), y: .value("L", item.liters))
                            .foregroundStyle(waterBlue.opacity(item.liters >= target ? 1.0 : 0.55))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Media", avg))
                        .foregroundStyle(waterBlue.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(String(format: "media %.1f L", avg))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(waterBlue)
                        }
                }
                .standardDateAxis()
                .standardYAxis(suffix: "L")
                .frame(height: 140)
            } bigValue: {
                if let today = waterData.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f L", today.liters))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(waterBlue)
                        Text(String(format: "target %.1f L", target))
                            .font(.system(size: 14)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    // ── Cache ─────────────────────────────────────────────────────────────

    private func rebuildDicts() {
        var md = [String: DayMacros]()
        for e in allEntries {
            md[e.dayKey, default: DayMacros()].kcal    += e.kcalSnapshot
            md[e.dayKey, default: DayMacros()].protein += e.proteinSnapshot
            md[e.dayKey, default: DayMacros()].carbs   += e.carbsSnapshot
            md[e.dayKey, default: DayMacros()].fat     += e.fatSnapshot
        }
        var wd = [String: Double]()
        for w in allWaterEntries { wd[w.dayKey, default: 0] += w.liters }
        macrosByDay = md; waterByDay = wd
    }
}
