import SwiftUI
import SwiftData

struct ResultsView: View {
    @Environment(\.modelContext) private var context
    @Binding var showSettings: Bool

    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]
    @Query(sort: \TargetHistory.effectiveDate) private var allTargetHistory: [TargetHistory]
    @Query private var allProfiles: [UserProfile]
    @Query private var allLimits: [AppLimits]

    private var limits: AppLimits? { allLimits.first }

    private var activeDays: [Date] {
        guard let lim = limits else { return [] }
        let start = Calendar.current.startOfDay(for: lim.startDate)
        let today = Calendar.current.startOfDay(for: Date())
        var days: [Date] = []; var cur = start
        while cur <= today { days.append(cur); cur = cur.adding(days: 1) }
        return days
    }

    private func log(for date: Date) -> DayLog? {
        let k = date.dateKey; return allLogs.first { $0.dateKey == k }
    }

    private func kcal(for date: Date) -> Double {
        let k = date.dateKey
        return allEntries.filter { $0.dayKey == k }.reduce(0) { $0 + $1.kcalSnapshot }
    }

    private func targets(for date: Date) -> TargetHistory? {
        let dayStart = Calendar.current.startOfDay(for: date)
        return allTargetHistory
            .filter { Calendar.current.startOfDay(for: $0.effectiveDate) <= dayStart }
            .max(by: { $0.effectiveDate < $1.effectiveDate })
            ?? allTargetHistory.min(by: { $0.effectiveDate < $1.effectiveDate })
    }

    // MARK: - Computed stats

    private var stats: Stats {
        guard let lim = limits else { return Stats() }

        // Pre-build O(n) lookup dicts — eliminates O(n²) per-day filtering
        let kcalByDay  = allEntries.reduce(into: [String: Double]()) { $0[$1.dayKey, default: 0] += $1.kcalSnapshot }
        let sportByDay = allSports.reduce(into: [String: Double]())  { $0[$1.dayKey, default: 0] += $1.kcalBurned }
        let logByDay   = allLogs.reduce(into: [String: DayLog]()) { $0[$1.dateKey] = $1 }

        // Running last-known weight (allLogs is sorted ascending by dateKey)
        var lastWeight: Double? = nil

        let profile = allProfiles.first
        var s = Stats()
        var daysWithKcal = 0, daysWithBurn = 0

        for date in activeDays {
            let key      = date.dateKey
            let log      = logByDay[key]
            if let w = log?.weight { lastWeight = w }

            let eaten    = kcalByDay[key] ?? 0
            let sportKcal = sportByDay[key] ?? 0
            let activityKcal = Double(log?.burnedKcal ?? 0) + sportKcal
            let steps    = log?.steps ?? 0
            let gym      = log?.gymColor ?? .rest

            s.totalSteps += steps
            if steps > 0 { s.daysWithSteps += 1 }
            if gym != .rest { s.gymDays += 1 }

            if eaten > 0 { s.totalKcalEaten += eaten; daysWithKcal += 1 }
            if activityKcal > 0 { s.totalKcalBurned += activityKcal; daysWithBurn += 1 }

            if eaten > 0 {
                var totalBurn = activityKcal
                if let p = profile, let h = p.heightCm, let bd = p.birthDate,
                   let w = lastWeight, w > 0 {
                    let age = Calendar.current.dateComponents([.year], from: bd, to: date).year ?? 0
                    totalBurn += calculateBMR(weightKg: w, heightCm: h, ageYears: age, sex: p.sex) * 1.2
                }
                let deficit = totalBurn - eaten
                s.totalDeficit += deficit
                s.fatLostKg    += deficit / 7700.0
            }
        }

        s.avgKcalEaten  = daysWithKcal > 0 ? s.totalKcalEaten / Double(daysWithKcal) : 0
        s.avgKcalBurned = daysWithBurn > 0 ? s.totalKcalBurned / Double(daysWithBurn) : 0
        s.avgSteps      = s.daysWithSteps > 0 ? Double(s.totalSteps) / Double(s.daysWithSteps) : 0

        let weights = activeDays.compactMap { logByDay[$0.dateKey]?.weight }
        if let first = weights.first, let last = weights.last, weights.count >= 2 {
            s.weightLostKg = first - last; s.hasWeightData = true
        }
        _ = lim
        return s
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    PageHeader("Risultati", subtitle: startSubtitle, showSettings: $showSettings)

                    let s = stats

                    ResultSection(title: "Corpo") {
                        ResultCard(
                            label: "Peso perso",
                            value: s.hasWeightData
                                ? (s.weightLostKg >= 0
                                    ? "-\(String(format: "%.1f", s.weightLostKg)) kg"
                                    : "+\(String(format: "%.1f", abs(s.weightLostKg))) kg")
                                : "Nessun dato",
                            color: s.hasWeightData ? (s.weightLostKg >= 0 ? .gymGreen : .gymOrange) : .muted,
                            icon: "scalemass.fill"
                        )
                        ResultCard(
                            label: "Grasso perso (stima)",
                            value: s.fatLostKg >= 0
                                ? "-\(String(format: "%.2f", s.fatLostKg)) kg"
                                : "+\(String(format: "%.2f", abs(s.fatLostKg))) kg",
                            color: s.fatLostKg >= 0 ? .gymGreen : .gymOrange,
                            icon: "flame.fill"
                        )
                    }

                    ResultSection(title: "Calorie") {
                        ResultCard(
                            label: "Deficit cumulativo",
                            value: s.totalDeficit >= 0
                                ? "-\(Int(s.totalDeficit)) kcal"
                                : "+\(Int(abs(s.totalDeficit))) kcal",
                            color: s.totalDeficit >= 0 ? .ringGreen : .gymOrange,
                            icon: "bolt.fill"
                        )
                        ResultCard(label: "Media calorie ingerite", value: "\(Int(s.avgKcalEaten)) kcal/g", color: .ringRed, icon: "fork.knife")
                        ResultCard(label: "Media calorie bruciate", value: "\(Int(s.avgKcalBurned)) kcal/g", color: .gymOrange, icon: "figure.run")
                    }

                    ResultSection(title: "Attività") {
                        ResultCard(label: "Giorni di palestra", value: "\(s.gymDays) giorni", color: .gymBlue, icon: "dumbbell.fill")
                        ResultCard(label: "Passi totali", value: s.totalSteps.stepsFormatted, color: .ringBlue, icon: "shoeprints.fill")
                        ResultCard(label: "Media passi/giorno", value: Int(s.avgSteps).stepsFormatted, color: .ringBlue, icon: "figure.walk")
                    }
                }
                .padding(.bottom, 120)
            }
        )
    }

    private static let startDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT"); f.dateFormat = "d MMM yyyy"; return f
    }()

    private var startSubtitle: String {
        guard let lim = limits else { return "" }
        return "Dal \(ResultsView.startDateFormatter.string(from: lim.startDate))"
    }
}

// MARK: - Stats model

struct Stats {
    var hasWeightData: Bool = false
    var weightLostKg: Double = 0
    var fatLostKg: Double = 0
    var totalDeficit: Double = 0
    var totalKcalEaten: Double = 0
    var totalKcalBurned: Double = 0
    var avgKcalEaten: Double = 0
    var avgKcalBurned: Double = 0
    var gymDays: Int = 0
    var totalSteps: Int = 0
    var daysWithSteps: Int = 0
    var avgSteps: Double = 0
}

// MARK: - UI Components

struct ResultSection<Content: View>: View {
    let title: String; let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title).padding(.horizontal, 20)
            content
        }
    }
}

struct ResultCard: View {
    let label: String; let value: String; let color: Color; let icon: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 13)).foregroundColor(.muted)
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(color)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
}
