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

    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allLimits: [AppLimits]
    @Query private var allSports: [SportEntry]
    @Query(sort: \TargetHistory.effectiveDate) private var allTargetHistory: [TargetHistory]
    @Query private var allProfiles: [UserProfile]
    @Query private var allWaterEntries: [WaterEntry]
    @Query(sort: \WorkoutSession.date) private var allWorkoutSessions: [WorkoutSession]

    @State private var period: ChartPeriod = .week

    // Gym charts state
    @State private var selectedExercise: String = ""
    private enum GymPeriod: String, CaseIterable {
        case oneMonth = "1m"; case threeMonths = "3m"; case sixMonths = "6m"; case oneYear = "1a"
        var days: Int {
            switch self { case .oneMonth: 30; case .threeMonths: 90; case .sixMonths: 180; case .oneYear: 365 }
        }
    }
    @State private var gymPeriod: GymPeriod = .threeMonths

    // Cached lookup dicts — rebuilt in O(n) on data change, O(1) per lookup in charts
    @State private var kcalByDay: [String: Double] = [:]
    @State private var proteinByDay: [String: Double] = [:]
    @State private var sportKcalByDay: [String: Double] = [:]
    @State private var waterByDay: [String: Double] = [:]
    @State private var logByDay: [String: DayLog] = [:]
    @State private var sortedWeights: [(String, Double)] = []

    private var dataFingerprint: Int {
        allEntries.count &* 31 &+ allLogs.count &* 37
            &+ allSports.count &* 41 &+ allWaterEntries.count &* 43
    }

    private var dates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<period.days).reversed().map { today.adding(days: -$0) }
    }

    // O(1) dict-based lookups (dicts rebuilt via rebuildDicts on data change)
    private func log(for date: Date) -> DayLog? { logByDay[date.dateKey] }
    private func kcal(for date: Date) -> Double  { kcalByDay[date.dateKey] ?? 0 }
    private func protein(for date: Date) -> Double { proteinByDay[date.dateKey] ?? 0 }
    private func sportKcal(for date: Date) -> Double { sportKcalByDay[date.dateKey] ?? 0 }
    private func water(for date: Date) -> Double { waterByDay[date.dateKey] ?? 0 }

    // allTargetHistory is sorted ascending by @Query — use last(where:) for O(n) with small n
    private func targets(for date: Date) -> TargetHistory? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return allTargetHistory.last {
            Calendar.current.startOfDay(for: $0.effectiveDate) <= dayStart
        } ?? allTargetHistory.first
    }

    // sortedWeights is [(dateKey, weight)] ascending — last(where:) is O(n) on typically tiny array
    private func weight(for date: Date) -> Double? {
        sortedWeights.last { $0.0 <= date.dateKey }?.1
    }

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

    private func fatLossData() -> [(date: Date, kg: Double)] {
        let hasSomeData = dates.contains { kcal(for: $0) > 0 || (log(for: $0)?.steps ?? 0) > 0 }
        guard hasSomeData else { return [] }
        var cumulative = 0.0
        var result: [(Date, Double)] = []
        for date in dates {
            let eaten = kcal(for: date)
            if eaten == 0 && (log(for: date)?.burnedKcal ?? 0) == 0 { continue }
            let deficit = totalDailyBurn(for: date) - eaten
            cumulative += deficit / 7700.0
            result.append((date, cumulative))
        }
        return result
    }

    // Gym chart helpers
    private var exercisesInSessions: [String] {
        var seen = Set<String>()
        var result = [String]()
        for sess in allWorkoutSessions.reversed() {
            for e in sess.entries where !seen.contains(e.exerciseName) {
                seen.insert(e.exerciseName); result.append(e.exerciseName)
            }
        }
        return result.sorted()
    }

    private var gymSessionsInPeriod: [WorkoutSession] {
        let cutoff = Calendar.current.startOfDay(for: Date()).adding(days: -gymPeriod.days)
        return allWorkoutSessions.filter { $0.date >= cutoff }
    }

    private var maxWeightData: [(Date, Double)] {
        guard !selectedExercise.isEmpty else { return [] }
        return gymSessionsInPeriod.compactMap { sess in
            guard let entry = sess.entries.first(where: { $0.exerciseName == selectedExercise }) else { return nil }
            let maxW = entry.sets.map { $0.weight }.max() ?? 0
            return maxW > 0 ? (sess.date, maxW) : nil
        }
    }

    private var volumeData: [(Date, Double)] {
        guard !selectedExercise.isEmpty else { return [] }
        return gymSessionsInPeriod.compactMap { sess in
            guard let entry = sess.entries.first(where: { $0.exerciseName == selectedExercise }) else { return nil }
            let vol = entry.sets.filter(\.completed).reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            return vol > 0 ? (sess.date, vol) : nil
        }
    }

    // Rebuild all lookup dicts in O(n) — called on appear and on data count changes
    private func rebuildDicts() {
        var kd = [String: Double](), pd = [String: Double]()
        for e in allEntries { kd[e.dayKey, default: 0] += e.kcalSnapshot; pd[e.dayKey, default: 0] += e.proteinSnapshot }
        var sd = [String: Double]()
        for s in allSports { sd[s.dayKey, default: 0] += s.kcalBurned }
        var wd = [String: Double]()
        for w in allWaterEntries { wd[w.dayKey, default: 0] += w.liters }
        var ld = [String: DayLog]()
        var sw = [(String, Double)]()
        for log in allLogs { // sorted ascending
            ld[log.dateKey] = log
            if let w = log.weight { sw.append((log.dateKey, w)) }
        }
        kcalByDay = kd; proteinByDay = pd; sportKcalByDay = sd
        waterByDay = wd; logByDay = ld; sortedWeights = sw
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

                    // ACQUA
                    let waterData = dates.map { (date: $0, liters: water(for: $0)) }
                    let daysWithWater = waterData.filter { $0.liters > 0 }
                    let avgWater = daysWithWater.isEmpty ? 0.0 : daysWithWater.map { $0.liters }.reduce(0, +) / Double(daysWithWater.count)
                    let waterTarget = allLimits.first?.waterTarget ?? 2.0
                    if !daysWithWater.isEmpty {
                        ChartCard(title: "Acqua") {
                            Chart {
                                ForEach(waterData, id: \.date) { item in
                                    BarMark(x: .value("Data", item.date, unit: .day), y: .value("L", item.liters))
                                        .foregroundStyle(Color(hex: "5AC8FA").opacity(item.liters >= waterTarget ? 1.0 : 0.55))
                                        .cornerRadius(6)
                                }
                                if avgWater > 0 {
                                    RuleMark(y: .value("Media", avgWater))
                                        .foregroundStyle(Color(hex: "5AC8FA").opacity(0.8))
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                        .annotation(position: .top, alignment: .leading) {
                                            Text(String(format: "media %.1f L", avgWater))
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(Color(hex: "5AC8FA"))
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
                                    AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.1fL", d)).font(.system(size: 9)).foregroundStyle(Color.muted) } }
                                    AxisGridLine().foregroundStyle(Color.brd)
                                }
                            }
                            .frame(height: 140)
                        } bigValue: {
                            if let today = waterData.last {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f L", today.liters))
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "5AC8FA"))
                                    Text(String(format: "target %.1f L", waterTarget))
                                        .font(.system(size: 14)).foregroundColor(.muted)
                                    if avgWater > 0 {
                                        Spacer()
                                        Text(String(format: "media %.1f L", avgWater))
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "5AC8FA"))
                                    }
                                }
                            }
                        }
                    }
                    // PROGRESSIONE ESERCIZI
                    gymChartsSection
                }
                .padding(.bottom, 120)
            }
        )
        .onAppear {
            rebuildDicts()
            if selectedExercise.isEmpty, let first = exercisesInSessions.first {
                selectedExercise = first
            }
        }
        .onChange(of: dataFingerprint) { rebuildDicts() }
        .onChange(of: allWorkoutSessions.count) {
            if selectedExercise.isEmpty, let first = exercisesInSessions.first {
                selectedExercise = first
            }
        }
    }

    // MARK: - Gym Charts Section

    private var gymChartsSection: some View {
        Group {
            if exercisesInSessions.isEmpty {
                ChartCard(title: "Progressione Esercizi") {
                    VStack(spacing: 10) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 32)).foregroundColor(.muted)
                        Text("Completa un allenamento\nper vedere i progressi")
                            .font(.system(size: 13)).foregroundColor(.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                } bigValue: { EmptyView() }
            } else {
                // Controls card
                HTCard {
                    VStack(spacing: 12) {
                        SectionLabel(text: "Progressione Esercizi")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Menu {
                            ForEach(exercisesInSessions, id: \.self) { name in
                                Button(name) { selectedExercise = name }
                            }
                        } label: {
                            HStack {
                                Text(selectedExercise.isEmpty ? "Seleziona esercizio" : selectedExercise)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedExercise.isEmpty ? .muted : .txt)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12)).foregroundColor(.muted)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        }
                        Picker("", selection: $gymPeriod) {
                            ForEach(GymPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 20)

                // Max weight chart
                if !maxWeightData.isEmpty {
                    ChartCard(title: "Peso massimo") {
                        Chart(maxWeightData, id: \.0) { date, w in
                            LineMark(x: .value("Data", date), y: .value("kg", w))
                                .foregroundStyle(Color.gymOrange).interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            PointMark(x: .value("Data", date), y: .value("kg", w))
                                .foregroundStyle(Color.gymOrange).symbolSize(40)
                            AreaMark(x: .value("Data", date), y: .value("kg", w))
                                .foregroundStyle(Color.gymOrange.opacity(0.12).gradient)
                                .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted).font(.system(size: 10))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel {
                                    if let d = v.as(Double.self) {
                                        Text("\(d.formatted1) kg").font(.system(size: 9)).foregroundStyle(Color.muted)
                                    }
                                }
                                AxisGridLine().foregroundStyle(Color.brd)
                            }
                        }
                        .frame(height: 160)
                    } bigValue: {
                        if let last = maxWeightData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(last.1.formatted1) kg")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.gymOrange)
                                Text("massimo").font(.system(size: 14)).foregroundColor(.muted)
                                if maxWeightData.count > 1 {
                                    let delta = last.1 - maxWeightData[0].1
                                    Text(delta >= 0 ? "+\(delta.formatted1)" : delta.formatted1)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(delta >= 0 ? .gymGreen : .muted)
                                }
                            }
                        }
                    }
                }

                // Volume chart
                if !volumeData.isEmpty {
                    ChartCard(title: "Volume totale (serie completate)") {
                        Chart(volumeData, id: \.0) { date, vol in
                            BarMark(x: .value("Data", date, unit: .day), y: .value("kg", vol))
                                .foregroundStyle(Color.gymBlue).cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted).font(.system(size: 10))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisValueLabel {
                                    if let d = v.as(Double.self) {
                                        Text("\(Int(d)) kg").font(.system(size: 9)).foregroundStyle(Color.muted)
                                    }
                                }
                                AxisGridLine().foregroundStyle(Color.brd)
                            }
                        }
                        .frame(height: 140)
                    } bigValue: {
                        if let last = volumeData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(last.1)) kg")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.gymBlue)
                                Text("volume").font(.system(size: 14)).foregroundColor(.muted)
                            }
                        }
                    }
                }
            }
        }
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
