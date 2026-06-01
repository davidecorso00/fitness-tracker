import SwiftUI
import SwiftData
import Charts

// MARK: - PredictionsView (standalone page)

struct PredictionsView: View {
    @Binding var showSettings: Bool

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    PageHeader("Predizioni", showSettings: $showSettings)
                    WeightGoalSection()
                }
                .padding(.bottom, 120)
            }
        )
    }
}

// MARK: - WeightGoalSection

struct WeightGoalSection: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DayLog.dateKey) private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]
    @Query private var allProfiles: [UserProfile]
    @Query private var allLimits: [AppLimits]

    @State private var editing: LimitField?

    private var limits: AppLimits? { allLimits.first }
    private var targetWeight: Double { limits?.targetWeight ?? 0 }
    private var targetDate: Date? { limits?.targetDate }
    private var profile: UserProfile? { allProfiles.first }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    private static let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM yyyy"; return f
    }()

    private func date(from key: String) -> Date? { Self.dayFmt.date(from: key) }

    // MARK: - Lookups

    private var kcalByDay: [String: Double] {
        var d: [String: Double] = [:]
        for e in allEntries { d[e.dayKey, default: 0] += e.kcalSnapshot }
        return d
    }
    private var sportByDay: [String: Double] {
        var d: [String: Double] = [:]
        for s in allSports { d[s.dayKey, default: 0] += s.kcalBurned }
        return d
    }

    // MARK: - Current weight

    private var currentWeight: Double? {
        allLogs.last(where: { $0.weight != nil })?.weight
    }

    // MARK: - Burn calculation

    private func dailyBurn(log: DayLog) -> Double {
        guard let d = date(from: log.dateKey) else { return 0 }
        let activity = Double(log.burnedKcal) + (sportByDay[log.dateKey] ?? 0)
        if let p = profile, let h = p.heightCm, let b = p.birthDate,
           let w = log.weight, w > 0 {
            let age = Calendar.current.dateComponents([.year], from: b, to: d).year ?? 0
            return calculateBMR(weightKg: w, heightCm: h, ageYears: age, sex: p.sex) * 1.2 + activity
        }
        return activity
    }

    // MARK: - Window stats

    struct DeficitWindow {
        let label: String; let avgDeficit: Double; let count: Int
    }

    private func window(_ n: Int, label: String) -> DeficitWindow {
        let todayKey = Date().dateKey
        let cutoffKey = Calendar.current.startOfDay(for: Date()).adding(days: -n).dateKey
        let kcal = kcalByDay
        let qualifying = allLogs.filter {
            $0.dateKey > cutoffKey && $0.dateKey <= todayKey &&
            $0.weight != nil && (kcal[$0.dateKey] ?? 0) > 0
        }
        guard !qualifying.isEmpty else { return DeficitWindow(label: label, avgDeficit: 0, count: 0) }
        let total = qualifying.reduce(0.0) { $0 + dailyBurn(log: $1) - (kcal[$1.dateKey] ?? 0) }
        return DeficitWindow(label: label, avgDeficit: total / Double(qualifying.count), count: qualifying.count)
    }

    private var w7:  DeficitWindow { window(7,  label: "7 gg") }
    private var w14: DeficitWindow { window(14, label: "14 gg") }
    private var w30: DeficitWindow { window(30, label: "30 gg") }

    private var dailyKgChange: Double { w30.count >= 2 ? w30.avgDeficit / 7700.0 : 0 }

    // MARK: - Projections

    private var kgToGoal: Double? {
        guard let cw = currentWeight, targetWeight > 0 else { return nil }
        return cw - targetWeight
    }

    private var estimatedDays: Int? {
        guard let kg = kgToGoal, abs(dailyKgChange) > 0.0001 else { return nil }
        let days = kg / dailyKgChange
        return days > 0 ? Int(ceil(days)) : nil
    }

    private var estimatedDate: Date? {
        guard let d = estimatedDays else { return nil }
        return Calendar.current.startOfDay(for: Date()).adding(days: d)
    }

    private var requiredDailyDeficit: Double? {
        guard let td = targetDate, let kg = kgToGoal, kg != 0 else { return nil }
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()), to: td).day ?? 0
        guard days > 0 else { return nil }
        return kg * 7700.0 / Double(days)
    }

    private var wrongDirection: Bool {
        guard let kg = kgToGoal else { return false }
        return kg > 0 ? dailyKgChange < 0 : dailyKgChange > 0
    }

    private var paceInsufficient: Bool {
        guard let td = targetDate, let estD = estimatedDays else { return false }
        let daysLeft = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()), to: td).day ?? 0
        return daysLeft > 0 && estD > daysLeft
    }

    // MARK: - Chart data

    private var actualPoints: [(date: Date, weight: Double)] {
        allLogs.compactMap { log in
            guard let w = log.weight, let d = date(from: log.dateKey) else { return nil }
            return (d, w)
        }
    }

    private var projectionPoints: [(date: Date, weight: Double)] {
        guard let cw = currentWeight, w30.count >= 2, abs(dailyKgChange) > 0.0001 else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        var maxDays = 90
        if let td = targetDate {
            maxDays = max(Calendar.current.dateComponents([.day], from: today, to: td).day ?? 90 + 30, 90)
        } else if let est = estimatedDays {
            maxDays = min(est + 30, 365)
        }
        var pts: [(Date, Double)] = []
        var w = cw
        for i in 0...maxDays {
            pts.append((today.adding(days: i), w))
            w += dailyKgChange
        }
        return pts
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Predizioni").padding(.horizontal, 20)
            goalSettingsCard
            if targetWeight > 0 {
                statusCard
                deficitWindowsCard
                if !actualPoints.isEmpty || !projectionPoints.isEmpty {
                    projectionChartCard
                }
                insightsCard
            }
        }
        .sheet(item: $editing) { LimitEditSheet(field: $0) }
    }

    // MARK: - Sub-views

    @ViewBuilder private var goalSettingsCard: some View {
        if let lim = limits {
            LimitGroup(title: "Obiettivo peso") {
                LimitRow(label: "Peso obiettivo", value: lim.targetWeight, unit: "kg") {
                    editing = LimitField(label: "Peso obiettivo", unit: "kg", current: lim.targetWeight) {
                        lim.targetWeight = $0; try? context.save()
                    }
                }
                HStack {
                    Text("Data obiettivo")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "cccccc"))
                    Spacer()
                    if lim.targetDate != nil {
                        DatePicker("", selection: Binding(
                            get: { lim.targetDate ?? Date().adding(days: 90) },
                            set: { lim.targetDate = $0; try? context.save() }
                        ), in: Date()..., displayedComponents: .date)
                        .labelsHidden().colorScheme(.dark).tint(.acc2)
                        Button {
                            lim.targetDate = nil; try? context.save()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.muted)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("Aggiungi") {
                            lim.targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
                            try? context.save()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.acc2)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 13)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    @ViewBuilder private var statusCard: some View {
        let cw = currentWeight
        let kg = kgToGoal
        let alreadyThere = kg.map { abs($0) < 0.5 } ?? false
        let color: Color = alreadyThere ? .acc : (kg ?? 1 > 0 ? .gymOrange : .gymBlue)

        HTCard {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peso attuale")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.5).textCase(.uppercase)
                    Text(cw.map { String(format: "%.1f kg", $0) } ?? "–")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.txt)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    if alreadyThere {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundColor(.acc)
                        Text("Obiettivo\nraggiunto").font(.system(size: 11, weight: .bold)).foregroundColor(.acc)
                            .multilineTextAlignment(.center)
                    } else if let kg = kg {
                        Text(String(format: "%.1f kg", abs(kg)))
                            .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(color)
                        Text(kg > 0 ? "da perdere" : "sotto target")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Obiettivo")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.5).textCase(.uppercase)
                    Text(String(format: "%.1f kg", targetWeight))
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.gymOrange)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var deficitWindowsCard: some View {
        HTCard {
            VStack(spacing: 10) {
                SectionLabel(text: "Deficit / surplus medio").frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    ForEach([w7, w14, w30], id: \.label) { win in
                        deficitCell(win)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func deficitCell(_ win: DeficitWindow) -> some View {
        VStack(spacing: 4) {
            Text(win.label)
                .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.4).textCase(.uppercase)
            if win.count == 0 {
                Text("–").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.muted)
            } else {
                Text("\(win.avgDeficit >= 0 ? "-" : "+")\(Int(abs(win.avgDeficit)))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(win.avgDeficit >= 0 ? .acc : .gymOrange)
                Text("kcal/g").font(.system(size: 10)).foregroundColor(.muted)
            }
            Text(win.count > 0 ? "\(win.count) gg utili" : "nessun dato")
                .font(.system(size: 10)).foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var projectionChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Grafico proiezione").padding(.horizontal, 20)
            WeightProjectionChart(
                actualPoints: actualPoints,
                projectedPoints: projectionPoints,
                targetWeight: targetWeight,
                targetDate: targetDate
            )
            .frame(height: 220)
            .padding(.horizontal, 4).padding(.vertical, 12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                legendItem(color: .acc, dash: false, label: "Peso reale")
                legendItem(color: .muted, dash: true, label: "Proiezione")
                legendItem(color: .gymOrange, dash: true, label: "Obiettivo")
            }
            .padding(.horizontal, 24).padding(.bottom, 4)
        }
    }

    private func legendItem(color: Color, dash: Bool, label: String) -> some View {
        HStack(spacing: 5) {
            if dash {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(color).frame(width: 5, height: 2)
                    }
                }
            } else {
                Rectangle().fill(color).frame(width: 16, height: 2)
            }
            Text(label).font(.system(size: 11)).foregroundColor(.muted)
        }
    }

    @ViewBuilder private var insightsCard: some View {
        if wrongDirection {
            warningBanner(
                icon: "arrow.up.right.circle.fill",
                color: .gymOrange,
                title: "Ritmo contrario all'obiettivo",
                body: "Negli ultimi 30 giorni sei in surplus calorico. Riduci le calorie per tornare in deficit."
            )
        } else if let cw = currentWeight, abs(cw - targetWeight) < 0.5 {
            EmptyView()
        } else {
            HTCard {
                VStack(spacing: 10) {
                    if let ed = estimatedDate {
                        insightRow(
                            icon: "calendar.badge.clock",
                            label: "Data stimata (ritmo attuale)",
                            value: Self.displayFmt.string(from: ed),
                            color: paceInsufficient ? .gymOrange : .acc
                        )
                    } else if w30.count < 2 {
                        insightRow(icon: "calendar.badge.clock", label: "Data stimata", value: "Dati insufficienti", color: .muted)
                    }

                    if let req = requiredDailyDeficit {
                        Divider().overlay(Color.white.opacity(0.05))
                        insightRow(
                            icon: "bolt.fill",
                            label: "Deficit necessario per la data",
                            value: req > 0 ? "-\(Int(req)) kcal/g" : "+\(Int(abs(req))) kcal/g",
                            color: req > 0 ? .ringGreen : .gymOrange
                        )
                    }

                    if paceInsufficient {
                        Divider().overlay(Color.white.opacity(0.05))
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.gymOrange).font(.system(size: 13))
                            Text("Il ritmo attuale non è sufficiente a raggiungere l'obiettivo entro la data impostata.")
                                .font(.system(size: 12)).foregroundColor(.gymOrange)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func insightRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 12)).foregroundColor(.muted)
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            }
            Spacer()
        }
    }

    private func warningBanner(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(color)
                Text(body).font(.system(size: 12)).foregroundColor(.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
}

// MARK: - Chart (isolated to avoid type-checker complexity)

private struct WeightProjectionChart: View {
    let actualPoints: [(date: Date, weight: Double)]
    let projectedPoints: [(date: Date, weight: Double)]
    let targetWeight: Double
    let targetDate: Date?

    var body: some View {
        Chart {
            ForEach(actualPoints, id: \.date) { pt in
                LineMark(x: .value("Data", pt.date), y: .value("Peso", pt.weight),
                         series: .value("Serie", "storico"))
                    .foregroundStyle(Color.acc)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Data", pt.date), y: .value("Peso", pt.weight))
                    .foregroundStyle(Color.acc)
                    .symbolSize(25)
            }
            ForEach(projectedPoints, id: \.date) { pt in
                LineMark(x: .value("Data", pt.date), y: .value("Peso", pt.weight),
                         series: .value("Serie", "proiezione"))
                    .foregroundStyle(Color.muted.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            if targetWeight > 0 {
                RuleMark(y: .value("Obiettivo", targetWeight))
                    .foregroundStyle(Color.gymOrange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("obiettivo").font(.system(size: 9)).foregroundColor(.gymOrange).padding(.trailing, 4)
                    }
            }
            if let td = targetDate {
                RuleMark(x: .value("Data obiettivo", td))
                    .foregroundStyle(Color.gymOrange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Image(systemName: "flag.fill").font(.system(size: 9)).foregroundColor(.gymOrange)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.muted).font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(String(format: "%.0f", v)).foregroundStyle(Color.muted).font(.system(size: 9))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }
}
