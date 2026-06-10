import SwiftUI
import SwiftData
import Charts

// MARK: - Grafici: panoramica a categorie con drill-down
//
// Livello 1 (questa schermata): una card riassuntiva per area con il dato
// chiave e un mini-grafico. Livello 2: schermata dedicata per categoria con
// i grafici a piena dimensione e il selettore di periodo unificato.

enum ChartCategory: Hashable {
    case nutrition, body, activity, gym, run
}

struct ChartsView: View {
    @Binding var showSettings: Bool

    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allLimits: [AppLimits]
    @Query(sort: \WorkoutSession.date) private var allWorkoutSessions: [WorkoutSession]
    @Query(sort: \RunSession.date) private var allRunSessions: [RunSession]

    private var last7Days: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).reversed().map { today.adding(days: -$0) }
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        PageHeader("Grafici", subtitle: "I tuoi progressi per area", showSettings: $showSettings)

                        VStack(spacing: 10) {
                            NavigationLink(value: ChartCategory.nutrition) { nutritionCard }
                            NavigationLink(value: ChartCategory.body) { bodyCard }
                            NavigationLink(value: ChartCategory.activity) { activityCard }
                            NavigationLink(value: ChartCategory.gym) { gymCard }
                            NavigationLink(value: ChartCategory.run) { runCard }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 120)
                    }
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ChartCategory.self) { category in
                switch category {
                case .nutrition: ChartsNutritionView()
                case .body:      ChartsBodyView()
                case .activity:  ChartsActivityView()
                case .gym:       ChartsGymView()
                case .run:       ChartsRunStatsView()
                }
            }
        }
    }

    // ── Card panoramica ───────────────────────────────────────────────────

    private var kcalByDay: [String: Double] {
        // Solo gli ultimi 7 giorni: filtro leggero per la panoramica
        let weekKeys = Set(last7Days.map(\.dateKey))
        return allEntries.reduce(into: [String: Double]()) { acc, e in
            if weekKeys.contains(e.dayKey) { acc[e.dayKey, default: 0] += e.kcalSnapshot }
        }
    }

    private var nutritionCard: some View {
        let kcal = kcalByDay
        let todayKcal = kcal[Date().dateKey] ?? 0
        let target = allLimits.first?.kcalTarget ?? 2255
        return OverviewCard(
            title: "Nutrizione", icon: "fork.knife", color: .ringRed,
            keyValue: "\(Int(todayKcal))",
            keyLabel: "/ \(Int(target)) kcal oggi"
        ) {
            MiniBars(values: last7Days.map { kcal[$0.dateKey] ?? 0 }, color: .ringRed)
        }
    }

    private var bodyCard: some View {
        let weights = allLogs.compactMap(\.weight)
        let recent = Array(weights.suffix(30))
        let last = recent.last
        return OverviewCard(
            title: "Corpo", icon: "figure", color: .gymGreen,
            keyValue: last.map { $0.formatted1 } ?? "—",
            keyLabel: last != nil ? "kg" : "nessun peso"
        ) {
            if recent.count > 1 {
                MiniLine(values: recent, color: .gymGreen)
            } else {
                MiniBars(values: [0, 0, 0, 0, 0, 0, 0], color: .gymGreen)
            }
        }
    }

    private var activityCard: some View {
        let logByDay = Dictionary(allLogs.map { ($0.dateKey, $0) }, uniquingKeysWith: { f, _ in f })
        let todaySteps = logByDay[Date().dateKey]?.steps ?? 0
        return OverviewCard(
            title: "Attività", icon: "flame.fill", color: .ringBlue,
            keyValue: todaySteps.stepsFormatted,
            keyLabel: "passi oggi"
        ) {
            MiniBars(values: last7Days.map { Double(logByDay[$0.dateKey]?.steps ?? 0) }, color: .ringBlue)
        }
    }

    private var gymCard: some View {
        let cal = Calendar.current
        let week = cal.dateInterval(of: .weekOfYear, for: Date())
        let thisWeek = allWorkoutSessions.filter { week?.contains($0.date) ?? false }.count
        // Sessioni per settimana, ultime 7 settimane
        var byWeek = [Date: Double]()
        for s in allWorkoutSessions {
            if let ws = periodStart(of: s.date, component: .weekOfYear) { byWeek[ws, default: 0] += 1 }
        }
        let lastWeeks: [Double] = (0..<7).reversed().map { w in
            guard let thisStart = week?.start,
                  let ws = cal.date(byAdding: .weekOfYear, value: -w, to: thisStart) else { return 0 }
            return byWeek[ws] ?? 0
        }
        return OverviewCard(
            title: "Palestra", icon: "dumbbell.fill", color: .gymPink,
            keyValue: "\(thisWeek)",
            keyLabel: thisWeek == 1 ? "allenamento questa settimana" : "allenamenti questa settimana"
        ) {
            MiniBars(values: lastWeeks, color: .gymPink)
        }
    }

    private var runCard: some View {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())
        let weekKm = allRunSessions.reduce(0.0) {
            (week?.contains($1.date) ?? false) ? $0 + $1.distanceKm : $0
        }
        var kmByDay = [String: Double]()
        for r in allRunSessions { kmByDay[r.dayKey, default: 0] += r.distanceKm }
        return OverviewCard(
            title: "Corsa", icon: "figure.run", color: .gymCyan,
            keyValue: String(format: "%.1f km", weekKm),
            keyLabel: "questa settimana"
        ) {
            MiniBars(values: last7Days.map { kmByDay[$0.dateKey] ?? 0 }, color: .gymCyan)
        }
    }
}
