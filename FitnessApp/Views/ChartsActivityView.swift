import SwiftUI
import SwiftData
import Charts

// MARK: - Attività & costanza: heatmap calendario, passi

struct ChartsActivityView: View {
    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]
    @Query private var allRunSessions: [RunSession]
    @Query private var allWorkoutSessions: [WorkoutSession]
    @Query(sort: \TargetHistory.effectiveDate) private var allTargetHistory: [TargetHistory]
    @Query private var allLimits: [AppLimits]

    @State private var period: StatPeriod = .month

    /// Intensità attività per giorno (0–4: cibo, palestra, corsa, altro sport)
    @State private var intensityByDay: [String: Int] = [:]
    @State private var logByDay: [String: DayLog] = [:]

    private var dataFingerprint: Int {
        allEntries.count &* 31 &+ allLogs.count &* 37 &+ allSports.count &* 41
            &+ allRunSessions.count &* 47 &+ allWorkoutSessions.count &* 53
    }

    private var earliestDate: Date? {
        guard let first = allLogs.first?.dateKey else { return nil }
        return dateFromKey(first)
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heatmapCard
                        .padding(.top, 10)

                    PeriodPicker(period: $period)
                    stepsChart
                }
                .padding(.bottom, 120)
            }
        )
        .navigationTitle("Attività")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
        .onAppear { rebuildDicts() }
        .onChange(of: dataFingerprint) { rebuildDicts() }
    }

    // ── Heatmap costanza (ultime 18 settimane, stile GitHub) ──────────────

    private var heatmapWeeks: [[Date]] {
        // appCalendar parte di lunedì: le etichette L M M G V S D restano allineate
        // anche con il telefono in una lingua che inizia la settimana di domenica.
        let cal = appCalendar
        let today = cal.startOfDay(for: Date())
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<18).reversed().map { w in
            let weekStart = cal.date(byAdding: .weekOfYear, value: -w, to: thisWeek) ?? thisWeek
            return (0..<7).map { weekStart.adding(days: $0) }
        }
    }

    private var heatmapCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Costanza · ultime 18 settimane")

                let weeks = heatmapWeeks
                let today = Calendar.current.startOfDay(for: Date())
                HStack(alignment: .top, spacing: 3) {
                    // Etichette giorni
                    VStack(spacing: 3) {
                        ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, d in
                            Text(d)
                                .font(.system(size: 8, weight: .semibold)).foregroundColor(.muted)
                                .frame(width: 10, height: 14)
                        }
                    }
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatColor(for: day, today: today))
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }

                // Legenda + streak
                HStack {
                    let streak = currentStreak()
                    if streak > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11)).foregroundColor(.gymOrange)
                            Text("\(streak) giorni di fila")
                                .font(.system(size: 12, weight: .bold)).foregroundColor(.txt)
                        }
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Meno").font(.system(size: 9)).foregroundColor(.muted)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(levelColor(level))
                                .frame(width: 10, height: 10)
                        }
                        Text("Più").font(.system(size: 9)).foregroundColor(.muted)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func heatColor(for day: Date, today: Date) -> Color {
        guard day <= today else { return Color.white.opacity(0.02) }
        return levelColor(intensityByDay[day.dateKey] ?? 0)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0:  return Color.white.opacity(0.06)
        case 1:  return Color.acc.opacity(0.30)
        case 2:  return Color.acc.opacity(0.55)
        case 3:  return Color.acc.opacity(0.80)
        default: return Color.acc
        }
    }

    /// Giorni consecutivi (fino a oggi/ieri) con almeno un'attività loggata.
    private func currentStreak() -> Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        if (intensityByDay[date.dateKey] ?? 0) == 0 { date = date.adding(days: -1) }
        while (intensityByDay[date.dateKey] ?? 0) > 0 {
            streak += 1
            date = date.adding(days: -1)
        }
        return streak
    }

    // ── Passi con linea obiettivo ─────────────────────────────────────────

    @ViewBuilder private var stepsChart: some View {
        let dates = period.dates(earliest: earliestDate)
        let stepsData = dates.map { (date: $0, steps: logByDay[$0.dateKey]?.steps ?? 0) }
        let target = allTargetHistory.last?.stepsTarget ?? allLimits.first?.stepsTarget ?? 10000
        let daysWith = stepsData.filter { $0.steps > 0 }
        let avg = daysWith.isEmpty ? 0 : daysWith.map(\.steps).reduce(0, +) / daysWith.count

        ChartCard(title: "Passi") {
            Chart {
                ForEach(stepsData, id: \.date) { item in
                    BarMark(x: .value("Data", item.date, unit: .day), y: .value("Passi", item.steps))
                        .foregroundStyle(Color.ringBlue.opacity(item.steps >= target ? 1.0 : 0.55))
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Obiettivo", target))
                    .foregroundStyle(Color.ringBlue.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("obiettivo \(target.stepsFormatted)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.ringBlue)
                    }
            }
            .standardDateAxis()
            .standardYAxis()
            .frame(height: 160)
        } bigValue: {
            if let today = stepsData.last {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(today.steps.stepsFormatted)
                        .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.gymBlue)
                    Text("oggi").font(.system(size: 14)).foregroundColor(.muted)
                    if avg > 0 {
                        Spacer()
                        Text("media \(avg.stepsFormatted)").font(.system(size: 13)).foregroundColor(.muted)
                    }
                }
            }
        }
    }

    // ── Cache ─────────────────────────────────────────────────────────────

    private func rebuildDicts() {
        var foodDays = Set<String>(), gymDays = Set<String>()
        var runDays = Set<String>(), sportDays = Set<String>()
        for e in allEntries { foodDays.insert(e.dayKey) }
        for s in allWorkoutSessions { gymDays.insert(s.dayKey) }
        for r in allRunSessions { runDays.insert(r.dayKey) }
        for s in allSports { sportDays.insert(s.dayKey) }

        var ld = [String: DayLog]()
        for log in allLogs {
            ld[log.dateKey] = log
            if log.gymColor != .rest { gymDays.insert(log.dateKey) }
        }

        var intensity = [String: Int]()
        for key in foodDays { intensity[key, default: 0] += 1 }
        for key in gymDays { intensity[key, default: 0] += 1 }
        for key in runDays { intensity[key, default: 0] += 1 }
        for key in sportDays { intensity[key, default: 0] += 1 }

        intensityByDay = intensity
        logByDay = ld
    }
}
