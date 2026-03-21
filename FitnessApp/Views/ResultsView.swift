import SwiftUI
import SwiftData

struct ResultsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Binding var showSettings: Bool

    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]

    @State private var limits: AppLimits?

    // Giorni dal startDate a oggi con almeno qualche dato
    private var activeDays: [Date] {
        guard let lim = limits else { return [] }
        let start = Calendar.current.startOfDay(for: lim.startDate)
        let today = Calendar.current.startOfDay(for: Date())
        var days: [Date] = []
        var cur = start
        while cur <= today {
            days.append(cur)
            cur = cur.adding(days: 1)
        }
        return days
    }

    private func log(for date: Date) -> DayLog? {
        let k = date.dateKey; return allLogs.first { $0.dateKey == k }
    }

    private func kcal(for date: Date) -> Double {
        let k = date.dateKey
        return allEntries.filter { $0.dayKey == k }.reduce(0) { $0 + $1.kcalSnapshot }
    }

    // MARK: - Computed stats

    private var stats: Stats {
        guard let lim = limits else { return Stats() }
        var s = Stats()
        var daysWithKcal = 0
        var daysWithBurn = 0

        for date in activeDays {
            let log = self.log(for: date)
            let eaten = kcal(for: date)
            let burned = Double(log?.burnedKcal ?? 0)
                + allSports.filter { $0.dayKey == date.dateKey }.reduce(0.0) { $0 + $1.kcalBurned }
            let steps = log?.steps ?? 0
            let gym = log?.gymColor ?? .rest

            // Passi
            s.totalSteps += steps
            if steps > 0 { s.daysWithSteps += 1 }

            // Palestra
            if gym != .rest { s.gymDays += 1 }

            // Calorie
            if eaten > 0 {
                s.totalKcalEaten += eaten
                daysWithKcal += 1
            }
            if burned > 0 {
                s.totalKcalBurned += burned
                daysWithBurn += 1
            }

            // Deficit: mangiato < target + bruciate
            if eaten > 0 {
                let deficit = lim.kcalTarget + burned - eaten
                s.totalDeficit += deficit
                // grasso: deficit / 7700 kg
                s.fatLostKg += deficit / 7700.0
            }
        }

        s.avgKcalEaten   = daysWithKcal > 0 ? s.totalKcalEaten / Double(daysWithKcal) : 0
        s.avgKcalBurned  = daysWithBurn > 0 ? s.totalKcalBurned / Double(daysWithBurn) : 0
        s.avgSteps       = daysWithSteps(s) > 0 ? Double(s.totalSteps) / Double(daysWithSteps(s)) : 0

        // Peso perso: primo peso vs ultimo peso registrati
        let weights = activeDays.compactMap { log(for: $0)?.weight }
        if let first = weights.first, let last = weights.last, weights.count >= 2 {
            s.weightLostKg = first - last
            s.hasWeightData = true
        }

        return s
    }

    private func daysWithSteps(_ s: Stats) -> Int { s.daysWithSteps }

    var body: some View {
        ZStack { Color.clear }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    PageHeader("Risultati", subtitle: startSubtitle, showSettings: $showSettings)

                    let s = stats

                    // CORPO
                    ResultSection(title: "Corpo") {
                        ResultCard(
                            label: "Peso perso",
                            value: s.hasWeightData
                                ? (s.weightLostKg >= 0
                                    ? "-\(String(format: "%.1f", s.weightLostKg)) kg"
                                    : "+\(String(format: "%.1f", abs(s.weightLostKg))) kg")
                                : "Nessun dato",
                            color: s.hasWeightData
                                ? (s.weightLostKg >= 0 ? .gymGreen : .gymOrange)
                                : .muted,
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

                    // CALORIE
                    ResultSection(title: "Calorie") {
                        ResultCard(
                            label: "Deficit cumulativo",
                            value: s.totalDeficit >= 0
                                ? "-\(Int(s.totalDeficit)) kcal"
                                : "+\(Int(abs(s.totalDeficit))) kcal",
                            color: s.totalDeficit >= 0 ? .ringGreen : .gymOrange,
                            icon: "bolt.fill"
                        )
                        ResultCard(
                            label: "Media calorie ingerite",
                            value: "\(Int(s.avgKcalEaten)) kcal/g",
                            color: .ringRed,
                            icon: "fork.knife"
                        )
                        ResultCard(
                            label: "Media calorie bruciate",
                            value: "\(Int(s.avgKcalBurned)) kcal/g",
                            color: .gymOrange,
                            icon: "figure.run"
                        )
                    }

                    // ATTIVITÀ
                    ResultSection(title: "Attività") {
                        ResultCard(
                            label: "Giorni di palestra",
                            value: "\(s.gymDays) giorni",
                            color: .gymBlue,
                            icon: "dumbbell.fill"
                        )
                        ResultCard(
                            label: "Passi totali",
                            value: s.totalSteps.stepsFormatted,
                            color: .ringBlue,
                            icon: "shoeprints.fill"
                        )
                        ResultCard(
                            label: "Media passi/giorno",
                            value: Int(s.avgSteps).stepsFormatted,
                            color: .ringBlue,
                            icon: "figure.walk"
                        )
                    }
                }
                .padding(.bottom, 120)
            }
        )
        .onAppear { limits = appState.limits(context: context) }
    }

    private static let startDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM yyyy"
        return f
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
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title).padding(.horizontal, 20)
            content
        }
    }
}

struct ResultCard: View {
    let label: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 13)).foregroundColor(.muted)
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(color)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
}
