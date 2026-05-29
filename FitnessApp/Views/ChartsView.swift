import SwiftUI
import SwiftData
import Charts

enum ChartPeriod: String, CaseIterable {
    case week    = "7g"
    case month   = "30g"
    case quarter = "3m"
    case all     = "Tutto"

    var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        case .all:     return 365
        }
    }
}

struct ChartsView: View {
    @Binding var showSettings: Bool
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allLimits: [AppLimits]
    @Query private var allSports: [SportEntry]
    @Query private var allTargetHistory: [TargetHistory]
    @Query private var allProfiles: [UserProfile]

    @State private var period: ChartPeriod = .week

    private var dates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<period.days).reversed().map { today.adding(days: -$0) }
    }

    private func log(for date: Date) -> DayLog? {
        let key = date.dateKey
        return allLogs.first { $0.dateKey == key }
    }

    private func kcal(for date: Date) -> Double {
        let key = date.dateKey
        return allEntries.filter { $0.dayKey == key }.reduce(0) { $0 + $1.kcalSnapshot }
    }

    private func protein(for date: Date) -> Double {
        let key = date.dateKey
        return allEntries.filter { $0.dayKey == key }.reduce(0) { $0 + $1.proteinSnapshot }
    }

    private func sportKcal(for date: Date) -> Double {
        let key = date.dateKey
        return allSports.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalBurned }
    }

    /// Target in vigore per una data (non retroattivo).
    private func targets(for date: Date) -> TargetHistory? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return allTargetHistory
            .filter { Calendar.current.startOfDay(for: $0.effectiveDate) <= dayStart }
            .max(by: { $0.effectiveDate < $1.effectiveDate })
            ?? allTargetHistory.min(by: { $0.effectiveDate < $1.effectiveDate })
    }

    /// Peso più recente registrato nei DayLog entro la data indicata.
    private func weight(for date: Date) -> Double? {
        let key = date.dateKey
        return allLogs
            .filter { $0.dateKey <= key && $0.weight != nil }
            .max(by: { $0.dateKey < $1.dateKey })?
            .weight
    }

    /// Spesa energetica totale del giorno: BMR × 1.2 + calorie attive HealthKit + sport.
    /// Se il profilo è incompleto ritorna solo le calorie attive.
    private func totalDailyBurn(for date: Date) -> Double {
        let log          = self.log(for: date)
        let activityKcal = Double(log?.burnedKcal ?? 0) + sportKcal(for: date)

        if let profile = allProfiles.first,
           let heightCm = profile.heightCm,
           let birthDate = profile.birthDate,
           let w = weight(for: date), w > 0 {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: date).year ?? 0
            let bmr = calculateBMR(weightKg: w, heightCm: heightCm, ageYears: age, sex: profile.sex) * 1.2
            return bmr + activityKcal
        }

        return activityKcal
    }

    /// Grasso perso/guadagnato cumulativo. Deficit = BMR×1.2 + attività − mangiato.
    private func fatLossData() -> [(date: Date, kg: Double)] {
        let datesWithData = dates.filter { kcal(for: $0) > 0 || (log(for: $0)?.steps ?? 0) > 0 }
        guard !datesWithData.isEmpty else { return [] }

        var cumulative = 0.0
        var result: [(Date, Double)] = []

        for date in dates {
            let eaten = kcal(for: date)
            if eaten == 0 && (log(for: date)?.burnedKcal ?? 0) == 0 { continue }
            let deficit  = totalDailyBurn(for: date) - eaten
            let kgChange = deficit / 7700.0
            cumulative  += kgChange
            result.append((date, cumulative))
        }
        return result
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grafici")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.txt)
                            Text("I tuoi progressi").font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                        }
                        Spacer()
                        GearBtn { showSettings = true }
                    }
                    .padding(.horizontal, 20).padding(.top, 16)

                    Picker("Periodo", selection: $period) {
                        ForEach(ChartPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    // GRASSO PERSO
                    let fatData = fatLossData()
                    if !fatData.isEmpty {
                        ChartCard(title: "Grasso perso (stima)") {
                            Chart(fatData, id: \.date) { item in
                                AreaMark(x: .value("Data", item.date), y: .value("kg", item.kg))
                                    .foregroundStyle(item.kg >= 0
                                        ? Color.gymGreen.opacity(0.2).gradient
                                        : Color.gymOrange.opacity(0.2).gradient)
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("Data", item.date), y: .value("kg", item.kg))
                                    .foregroundStyle(item.kg >= 0 ? Color.gymGreen : Color.gymOrange)
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                PointMark(x: .value("Data", item.date), y: .value("kg", item.kg))
                                    .foregroundStyle(item.kg >= 0 ? Color.gymGreen : Color.gymOrange)
                                    .symbolSize(25)
                                RuleMark(y: .value("Zero", 0))
                                    .foregroundStyle(Color.muted.opacity(0.4))
                                    .lineStyle(StrokeStyle(dash: [4, 4]))
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                        .foregroundStyle(Color.muted).font(.system(size: 10))
                                }
                            }
                            .chartYAxis {
                                AxisMarks { v in
                                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(d, specifier: "%.2f")kg").font(.system(size: 9)).foregroundStyle(Color.muted) } }
                                    AxisGridLine().foregroundStyle(Color.brd)
                                }
                            }
                            .frame(height: 180)
                        } bigValue: {
                            if let last = fatData.last {
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

                    // PESO
                    let weightData = dates.compactMap { d -> (Date, Double)? in
                        guard let w = log(for: d)?.weight else { return nil }
                        return (d, w)
                    }
                    if !weightData.isEmpty {
                        ChartCard(title: "Peso") {
                            Chart(weightData, id: \.0) { date, w in
                                LineMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen).interpolationMethod(.catmullRom)
                                AreaMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen.opacity(0.15).gradient).interpolationMethod(.catmullRom)
                                PointMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen).symbolSize(30)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                        .foregroundStyle(Color.muted).font(.system(size: 10))
                                }
                            }
                            .chartYAxis {
                                AxisMarks { v in
                                    AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                                    AxisGridLine().foregroundStyle(Color.brd)
                                }
                            }
                            .frame(height: 160)
                        } bigValue: {
                            if let last = weightData.last {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(last.1.formatted1).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.txt)
                                    Text("kg").font(.system(size: 14)).foregroundColor(.muted)
                                    if weightData.count > 1 {
                                        let delta = last.1 - weightData[0].1
                                        Text(delta >= 0 ? "+\(delta.formatted1)" : "\(delta.formatted1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(delta <= 0 ? .gymGreen : .gymOrange)
                                    }
                                }
                            }
                        }
                    }

                    // CALORIE (con media giornaliera)
                    let kcalData = dates.map { (date: $0, kcal: kcal(for: $0)) }
                    let todayKcalTarget = targets(for: Date())?.kcalTarget ?? allLimits.first?.kcalTarget ?? 2255
                    let daysWithKcal = kcalData.filter { $0.kcal > 0 }
                    let avgKcal = daysWithKcal.isEmpty ? 0.0 : daysWithKcal.map { $0.kcal }.reduce(0, +) / Double(daysWithKcal.count)
                    ChartCard(title: "Calorie") {
                        Chart {
                            ForEach(kcalData, id: \.date) { item in
                                let dayTarget = targets(for: item.date)?.kcalTarget ?? allLimits.first?.kcalTarget ?? 2255
                                BarMark(x: .value("Data", item.date, unit: .day), y: .value("kcal", item.kcal))
                                    .foregroundStyle(item.kcal > dayTarget ? Color.gymOrange : Color.ringRed)
                                    .cornerRadius(6)
                            }
                            if avgKcal > 0 {
                                RuleMark(y: .value("Media", avgKcal))
                                    .foregroundStyle(Color.gymOrange.opacity(0.7))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .annotation(position: .top, alignment: .leading) {
                                        Text("media \(Int(avgKcal))")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.gymOrange)
                                    }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted).font(.system(size: 10))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                                AxisGridLine().foregroundStyle(Color.brd)
                            }
                        }
                        .frame(height: 160)
                    } bigValue: {
                        if let today = kcalData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(today.kcal))")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(today.kcal > todayKcalTarget ? .gymOrange : .txt)
                                Text("/ \(Int(todayKcalTarget)) kcal").font(.system(size: 14)).foregroundColor(.muted)
                                if avgKcal > 0 {
                                    Spacer()
                                    Text("media \(Int(avgKcal))").font(.system(size: 13)).foregroundColor(.gymOrange)
                                }
                            }
                        }
                    }

                    // PALESTRA
                    ChartCard(title: "Palestra") {
                        HStack(spacing: 6) {
                            ForEach(dates.suffix(7), id: \.self) { date in
                                let gc = log(for: date)?.gymColor ?? .rest
                                VStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 10).fill(gc.color).frame(width: 34, height: 34)
                                    Text(shortDayLabel(date)).font(.system(size: 10, weight: .semibold)).foregroundColor(.muted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                    } bigValue: {
                        let active = dates.suffix(7).filter { (log(for: $0)?.gymColor ?? .rest) != .rest }.count
                        HStack(spacing: 4) {
                            Text("\(active)/7").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.gymBlue)
                            Text("allenamenti").font(.system(size: 14)).foregroundColor(.muted)
                        }
                    }

                    // PROTEINE
                    let protData = dates.map { (date: $0, p: protein(for: $0)) }
                    let todayProtTarget = targets(for: Date())?.proteinTarget ?? allLimits.first?.proteinTarget ?? 200
                    ChartCard(title: "Proteine") {
                        Chart(protData, id: \.date) { item in
                            LineMark(x: .value("Data", item.date), y: .value("g", item.p))
                                .foregroundStyle(Color.ringGreen).interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Data", item.date), y: .value("g", item.p))
                                .foregroundStyle(Color.ringGreen.opacity(0.15).gradient).interpolationMethod(.catmullRom)
                            RuleMark(y: .value("Target", todayProtTarget))
                                .foregroundStyle(Color.ringGreen.opacity(0.4))
                                .lineStyle(StrokeStyle(dash: [4, 4]))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted).font(.system(size: 10))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                                AxisGridLine().foregroundStyle(Color.brd)
                            }
                        }
                        .frame(height: 140)
                    } bigValue: {
                        if let today = protData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(today.p))g").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.acc2)
                                Text("target \(Int(todayProtTarget))g").font(.system(size: 14)).foregroundColor(.muted)
                            }
                        }
                    }

                    // PASSI (opacità basata su target del giorno)
                    let stepsData = dates.map { (date: $0, steps: log(for: $0)?.steps ?? 0) }
                    ChartCard(title: "Passi") {
                        Chart(stepsData, id: \.date) { item in
                            let dayStepsTarget = targets(for: item.date)?.stepsTarget ?? allLimits.first?.stepsTarget ?? 10000
                            BarMark(x: .value("Data", item.date, unit: .day), y: .value("Passi", item.steps))
                                .foregroundStyle(Color.ringBlue.opacity(item.steps >= dayStepsTarget ? 1.0 : 0.65))
                                .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted).font(.system(size: 10))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                                AxisGridLine().foregroundStyle(Color.brd)
                            }
                        }
                        .frame(height: 140)
                    } bigValue: {
                        if let today = stepsData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(today.steps.stepsFormatted)
                                    .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.gymBlue)
                                let avg = stepsData.isEmpty ? 0 : stepsData.map(\.steps).reduce(0, +) / stepsData.count
                                Text("media \(avg.stepsFormatted)").font(.system(size: 14)).foregroundColor(.muted)
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
        )
    }

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateFormat = "EEE"; return f
    }()

    private func shortDayLabel(_ date: Date) -> String {
        String(ChartsView.shortDayFormatter.string(from: date).prefix(3)).capitalized
    }
}

// MARK: - Chart Card

struct ChartCard<Chart: View, BigValue: View>: View {
    let title: String
    let chart: () -> Chart
    let bigValue: () -> BigValue

    init(title: String, @ViewBuilder chart: @escaping () -> Chart, @ViewBuilder bigValue: @escaping () -> BigValue) {
        self.title = title; self.chart = chart; self.bigValue = bigValue
    }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: title)
                bigValue()
                chart()
            }
        }
        .padding(.horizontal, 20)
    }
}
