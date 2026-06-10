import SwiftUI
import SwiftData
import Charts

// MARK: - Palestra: volume, bilanciamento muscoli, progressione e 1RM

struct ChartsGymView: View {
    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query(sort: \WorkoutSession.date) private var allWorkoutSessions: [WorkoutSession]

    @State private var period: StatPeriod = .threeMonths
    @State private var selectedExercise: String = ""

    private var earliestDate: Date? { allWorkoutSessions.first?.date }

    private var sessionsInPeriod: [WorkoutSession] {
        let start = period.startDate(earliest: earliestDate)
        return allWorkoutSessions.filter { $0.date >= start }
    }

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

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    PeriodPicker(period: $period)
                        .padding(.top, 10)

                    weekDotsCard
                    weeklyVolumeChart
                    muscleBalanceChart
                    exerciseProgressionSection
                }
                .padding(.bottom, 120)
            }
        )
        .navigationTitle("Palestra")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .onAppear {
            if selectedExercise.isEmpty, let first = exercisesInSessions.first {
                selectedExercise = first
            }
        }
    }

    // ── Ultima settimana (dots colore palestra) ───────────────────────────

    private var weekDotsCard: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let last7 = (0..<7).reversed().map { today.adding(days: -$0) }
        let logByDay = Dictionary(allLogs.map { ($0.dateKey, $0) }, uniquingKeysWith: { f, _ in f })

        return ChartCard(title: "Ultima settimana") {
            HStack(spacing: 6) {
                ForEach(last7, id: \.self) { date in
                    let gc = logByDay[date.dateKey]?.gymColor ?? .rest
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 10).fill(gc.color).frame(width: 34, height: 34)
                        Text(shortDayLabel(date)).font(.system(size: 10, weight: .semibold)).foregroundColor(.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
        } bigValue: {
            let active = last7.filter { (logByDay[$0.dateKey]?.gymColor ?? .rest) != .rest }.count
            HStack(spacing: 4) {
                Text("\(active)/7").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.gymBlue)
                Text("allenamenti").font(.system(size: 14)).foregroundColor(.muted)
            }
        }
    }

    // ── Volume settimanale (kg totali sollevati) ──────────────────────────

    private var weeklyVolumeData: [(key: Date, value: Double)] {
        var byWeek = [Date: Double]()
        for sess in sessionsInPeriod {
            guard let week = periodStart(of: sess.date, component: .weekOfYear) else { continue }
            let vol = sess.entries.reduce(0.0) { acc, entry in
                acc + entry.sets.filter(\.completed).reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
            byWeek[week, default: 0] += vol
        }
        return byWeek.sorted { $0.key < $1.key }
    }

    @ViewBuilder private var weeklyVolumeChart: some View {
        let data = weeklyVolumeData
        if !data.isEmpty {
            ChartCard(title: "Volume settimanale") {
                Chart(data, id: \.key) { week, vol in
                    BarMark(x: .value("Settimana", week, unit: .weekOfYear), y: .value("kg", vol))
                        .foregroundStyle(Color.gymBlue).cornerRadius(5)
                }
                .standardDateAxis()
                .standardYAxis(suffix: " kg")
                .frame(height: 150)
            } bigValue: {
                if let current = data.last {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(current.value).stepsFormatted) kg")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.gymBlue)
                        Text("questa settimana").font(.system(size: 14)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    // ── Bilanciamento gruppi muscolari ────────────────────────────────────

    private var muscleBalanceData: [(key: String, value: Int)] {
        var byGroup = [String: Int]()
        for sess in sessionsInPeriod {
            for entry in sess.entries {
                let group = entry.exerciseMuscleGroup.isEmpty ? "Altro" : entry.exerciseMuscleGroup
                byGroup[group, default: 0] += entry.sets.filter(\.completed).count
            }
        }
        return byGroup.sorted { $0.value > $1.value }
    }

    @ViewBuilder private var muscleBalanceChart: some View {
        let data = muscleBalanceData
        if !data.isEmpty {
            let maxSets = max(data.first?.value ?? 1, 1)
            ChartCard(title: "Bilanciamento gruppi muscolari") {
                VStack(spacing: 8) {
                    ForEach(data, id: \.key) { group, sets in
                        HStack(spacing: 10) {
                            Text(group)
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
                                .frame(width: 86, alignment: .leading)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 12)
                                    Capsule()
                                        .fill(Color.gymPink.opacity(0.45 + 0.55 * Double(sets) / Double(maxSets)))
                                        .frame(width: geo.size.width * Double(sets) / Double(maxSets), height: 12)
                                }
                            }
                            .frame(height: 12)
                            Text("\(sets)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .monospacedDigit().foregroundColor(.txt)
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)
            } bigValue: {
                Text("Serie completate per gruppo nel periodo")
                    .font(.system(size: 12)).foregroundColor(.muted)
            }
        }
    }

    // ── Progressione esercizio: peso max, 1RM stimato, volume ─────────────

    private var exerciseSessionData: [(date: Date, maxW: Double, oneRM: Double, volume: Double)] {
        guard !selectedExercise.isEmpty else { return [] }
        return sessionsInPeriod.compactMap { sess in
            guard let entry = sess.entries.first(where: { $0.exerciseName == selectedExercise }) else { return nil }
            let sets = entry.sets.filter { $0.weight > 0 }
            guard !sets.isEmpty else { return nil }
            let maxW = sets.map(\.weight).max() ?? 0
            // Epley: 1RM = w × (1 + reps/30), sul set migliore
            let oneRM = sets.map { $0.weight * (1 + Double($0.reps) / 30) }.max() ?? 0
            let vol = entry.sets.filter(\.completed).reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            return (sess.date, maxW, oneRM, vol)
        }
    }

    @ViewBuilder private var exerciseProgressionSection: some View {
        if exercisesInSessions.isEmpty {
            ChartCard(title: "Progressione esercizi") {
                VStack(spacing: 10) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 32)).foregroundColor(.muted)
                    Text("Completa un allenamento\nper vedere i progressi")
                        .font(.system(size: 13)).foregroundColor(.muted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            } bigValue: { EmptyView() }
        } else {
            HTCard {
                VStack(spacing: 12) {
                    SectionLabel(text: "Progressione esercizi")
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
                }
            }
            .padding(.horizontal, 20)

            let data = exerciseSessionData
            if !data.isEmpty {
                // Peso massimo + 1RM stimato
                ChartCard(title: "Forza · peso max e 1RM stimato") {
                    Chart {
                        ForEach(data, id: \.date) { item in
                            LineMark(x: .value("Data", item.date), y: .value("kg", item.maxW),
                                     series: .value("Serie", "Max"))
                                .foregroundStyle(Color.gymOrange).interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                            PointMark(x: .value("Data", item.date), y: .value("kg", item.maxW))
                                .foregroundStyle(Color.gymOrange).symbolSize(30)
                        }
                        ForEach(data, id: \.date) { item in
                            LineMark(x: .value("Data", item.date), y: .value("kg", item.oneRM),
                                     series: .value("Serie", "1RM"))
                                .foregroundStyle(Color.gymPink.opacity(0.8))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .standardDateAxis()
                    .standardYAxis(suffix: " kg")
                    .frame(height: 170)
                } bigValue: {
                    if let last = data.last {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(last.maxW.formatted1) kg")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.gymOrange)
                                Text("max").font(.system(size: 13)).foregroundColor(.muted)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(last.oneRM.formatted1) kg")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.gymPink)
                                Text("1RM stim.").font(.system(size: 13)).foregroundColor(.muted)
                            }
                        }
                    }
                }

                // Volume per sessione
                ChartCard(title: "Volume per sessione") {
                    Chart(data, id: \.date) { item in
                        BarMark(x: .value("Data", item.date, unit: .day), y: .value("kg", item.volume))
                            .foregroundStyle(Color.gymBlue).cornerRadius(5)
                    }
                    .standardDateAxis()
                    .standardYAxis(suffix: " kg")
                    .frame(height: 140)
                } bigValue: {
                    if let last = data.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(last.volume)) kg")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.gymBlue)
                            Text("ultima sessione").font(.system(size: 14)).foregroundColor(.muted)
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
        String(Self.shortDayFormatter.string(from: date).prefix(3)).capitalized
    }
}
