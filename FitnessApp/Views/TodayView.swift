import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Binding var showSettings: Bool

    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]
    @Query private var allLimits: [AppLimits]
    @Query private var allProfiles: [UserProfile]
    @Query private var allWaterEntries: [WaterEntry]

    @State private var weightInput: String = ""
    @State private var appeared: Bool      = false
    @State private var showAddSport: Bool  = false

    private var currentKey: String { appState.currentDateKey }
    private var isFuture: Bool     { appState.currentDate.isFuture }

    private var dayLog: DayLog? {
        allLogs.first { $0.dateKey == currentKey }
    }

    private var limits: AppLimits? { allLimits.first }

    private var todayEntries: [FoodEntry] {
        allEntries.filter { $0.dayKey == currentKey }
    }

    private var todaySports: [SportEntry] {
        allSports.filter { $0.dayKey == currentKey }
    }

    private var totals: AppState.DayTotals {
        todayEntries.reduce(into: AppState.DayTotals()) { t, e in
            t.kcal         += e.kcalSnapshot
            t.protein      += e.proteinSnapshot
            t.carbs        += e.carbsSnapshot
            t.fat          += e.fatSnapshot
            t.fiber        += e.fiberSnapshot
            t.sugar        += e.sugarSnapshot
            t.saturatedFat += e.saturatedFatSnapshot
            t.salt         += e.saltSnapshot
        }
    }

    private var sportBurned: Double {
        todaySports.reduce(0.0) { $0 + $1.kcalBurned }
    }

    private var deficitStreak: Int { calcDeficitStreak() }

    // ── BMR helpers ──────────────────────────────────────────────────────

    private func weightOnOrBefore(dateKey: String) -> Double? {
        allLogs
            .filter { $0.dateKey <= dateKey && $0.weight != nil }
            .max(by: { $0.dateKey < $1.dateKey })?
            .weight
    }

    private func totalDailyBurn(dateKey: String, date: Date, extraSport: Double) -> Double {
        let log          = allLogs.first { $0.dateKey == dateKey }
        let activityKcal = Double(log?.burnedKcal ?? 0) + extraSport

        if let profile = allProfiles.first,
           let heightCm = profile.heightCm,
           let birthDate = profile.birthDate,
           let w = weightOnOrBefore(dateKey: dateKey), w > 0 {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: date).year ?? 0
            let bmr = calculateBMR(weightKg: w, heightCm: heightCm, ageYears: age, sex: profile.sex) * 1.2
            return bmr + activityKcal
        }

        return activityKcal
    }

    private var bmrToday: Double {
        guard let profile = allProfiles.first,
              let heightCm = profile.heightCm,
              let birthDate = profile.birthDate else { return 0 }
        let w = dayLog?.weight ?? lastKnownWeight ?? 0
        guard w > 0 else { return 0 }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: appState.currentDate).year ?? 0
        return calculateBMR(weightKg: w, heightCm: heightCm, ageYears: age, sex: profile.sex) * 1.2
    }

    private func calcDeficitStreak() -> Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        for _ in 0..<365 {
            let key   = date.dateKey
            let eaten = kcalEaten(for: key)
            guard eaten > 0 else {
                if date.isToday { date = date.adding(days: -1); continue }
                break
            }
            let sportKcal = allSports.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalBurned }
            let burned = totalDailyBurn(dateKey: key, date: date, extraSport: sportKcal)
            if eaten < burned { streak += 1 } else { break }
            date = date.adding(days: -1)
        }
        return streak
    }

    private func kcalEaten(for key: String) -> Double {
        allEntries.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalSnapshot }
    }

    private var lastKnownWeight: Double? {
        let today = Calendar.current.startOfDay(for: Date())
        var date = today.adding(days: -1)
        for _ in 0..<90 {
            let key = date.dateKey
            if let log = allLogs.first(where: { $0.dateKey == key }), let w = log.weight {
                return w
            }
            date = date.adding(days: -1)
        }
        return nil
    }

    private var todayWaterTotal: Double {
        allWaterEntries.filter { $0.dayKey == Date().dateKey }.reduce(0) { $0 + $1.liters }
    }

    private var todaySteps: Int {
        allLogs.first { $0.dateKey == Date().dateKey }?.steps ?? 0
    }

    private func writeWidgetData() {
        let k = Date().dateKey
        let kcal = allEntries.filter { $0.dayKey == k }.reduce(0.0) { $0 + $1.kcalSnapshot }
        let prot = allEntries.filter { $0.dayKey == k }.reduce(0.0) { $0 + $1.proteinSnapshot }
        WidgetDataWriter.write(
            kcalEaten: kcal,   kcalTarget:    limits?.kcalTarget    ?? 2255,
            proteinEaten: prot, proteinTarget: limits?.proteinTarget ?? 200,
            waterLiters: todayWaterTotal, waterTarget: limits?.waterTarget ?? 2.0,
            steps: todaySteps, stepsTarget: limits?.stepsTarget ?? 10000
        )
    }

    // ── Body ──────────────────────────────────────────────────────────────
    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Nav header
                    HStack {
                        NavBtn(icon: "chevron.left") { appState.goBack() }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(appState.currentDate.fullDisplay)
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                            let badge = appState.currentDate.displayLabel
                            if !badge.isEmpty {
                                Text(badge)
                                    .font(.system(size: 11, weight: .bold)).foregroundColor(.acc)
                                    .padding(.horizontal, 10).padding(.vertical, 3)
                                    .background(Color.acc.opacity(0.15), in: Capsule())
                            }
                        }
                        Spacer()
                        NavBtn(icon: "chevron.right", disabled: !appState.canGoForward) { appState.goForward() }
                        GearBtn { showSettings = true }.padding(.leading, 4)
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                    VStack(spacing: 14) {
                        // Streak
                        if deficitStreak > 0 {
                            HStack(spacing: 12) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.gymOrange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(deficitStreak) giorni in deficit")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                                    Text("Deficit calorico consecutivo")
                                        .font(.system(size: 12)).foregroundColor(.muted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // TRIPLE RING CARD
                        if let lim = limits {
                            let log           = dayLog ?? placeholderLog
                            let activityBurned = Double(log.burnedKcal) + sportBurned
                            let totalBurned   = bmrToday + activityBurned
                            TripleRingCard(
                                eaten: totals.kcal, kcalTarget: lim.kcalTarget,
                                protein: totals.protein, proteinTarget: lim.proteinTarget,
                                steps: log.steps, stepsTarget: lim.stepsTarget,
                                burned: totalBurned,
                                isFuture: isFuture, appeared: appeared
                            )
                        }

                        // Macronutrienti
                        if let lim = limits {
                            HTCard {
                                VStack(spacing: 8) {
                                    SectionLabel(text: "Macronutrienti").frame(maxWidth: .infinity, alignment: .leading)
                                    MacroBar(label: "Proteine",    value: totals.protein,      target: lim.proteinTarget,      color: .ringGreen)
                                    MacroBar(label: "Carboidrati", value: totals.carbs,        target: lim.carbsTarget,        color: .gymBlue)
                                    MacroBar(label: "Grassi",      value: totals.fat,          target: lim.fatTarget,          color: .gymOrange)
                                    Rectangle().fill(Color.brd).frame(height: 0.5).padding(.vertical, 2)
                                    MacroBar(label: "Fibre",      value: totals.fiber,        target: lim.fiberTarget,        color: .gymGreen,  small: true)
                                    MacroBar(label: "Zuccheri",   value: totals.sugar,        target: lim.sugarTarget,        color: .gymPink,   small: true)
                                    MacroBar(label: "Gr. saturi", value: totals.saturatedFat, target: lim.saturatedFatTarget, color: .gymOrange, small: true)
                                    MacroBar(label: "Sale",       value: totals.salt,          target: lim.saltTarget,        color: .muted,     small: true)
                                }
                            }
                        }

                        // Peso + Passi — uno sopra l'altro, full width
                        VStack(spacing: 10) {
                            // Peso: label in alto, poi input e bottone affiancati stessa altezza
                            HTCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    SectionLabel(text: "Peso kg")
                                    HStack(alignment: .top, spacing: 12) {
                                        BigInputField(placeholder: "0.0", value: $weightInput, color: .txt, fontSize: 22)
                                        Button { saveWeight() } label: {
                                            Text("Salva")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(maxHeight: .infinity)
                                                .padding(.horizontal, 26)
                                        }
                                        .buttonStyle(.plain)
                                        .background(Color.acc, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                }
                            }

                            if let lim = limits {
                                let log = dayLog ?? placeholderLog
                                HTCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        SectionLabel(text: "Passi")
                                        Text(log.steps.stepsFormatted)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundColor(.ringBlue)
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                                                Capsule()
                                                    .fill(Color.ringBlue)
                                                    .frame(width: geo.size.width * min(Double(log.steps) / Double(lim.stepsTarget), 1), height: 5)
                                            }
                                        }
                                        .frame(height: 5).padding(.top, 2)
                                        Text("/ \(lim.stepsTarget.stepsFormatted)")
                                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.muted)
                                    }
                                }
                            }
                        }

                        // Acqua
                        WaterCard(dateKey: currentKey, target: limits?.waterTarget ?? 2.0)

                        // Palestra — dots distribuiti su tutta la riga
                        if let log = dayLog {
                            HTCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel(text: "Palestra oggi")
                                    if #available(iOS 26.0, *) {
                                        GlassEffectContainer {
                                            HStack(spacing: 0) {
                                                ForEach(GymColor.allCases, id: \.self) { gc in
                                                    GymDot(gymColor: gc, isSelected: log.gymColor == gc) {
                                                        log.gymColor = gc
                                                        try? context.save()
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 0) {
                                            ForEach(GymColor.allCases, id: \.self) { gc in
                                                GymDot(gymColor: gc, isSelected: log.gymColor == gc) {
                                                    log.gymColor = gc
                                                    try? context.save()
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Sport
                        SportSectionView(
                            dateKey: appState.currentDateKey,
                            showAddSport: $showAddSport,
                            onChanged: {}
                        )
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
        )
        .onAppear {
            syncInputFields()
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appeared = true }
            appState.syncHealthKit(for: appState.currentDate, context: context)
            writeWidgetData()
        }
        .onChange(of: appState.currentDate) {
            appeared = false
            syncInputFields()
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) { appeared = true }
            appState.syncHealthKit(for: appState.currentDate, context: context)
        }
        .onChange(of: dayLog?.weight) { syncInputFields() }
        .onChange(of: allEntries.count) { writeWidgetData() }
        .onChange(of: todayWaterTotal) { writeWidgetData() }
        .onChange(of: todaySteps) { writeWidgetData() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private var placeholderLog: DayLog {
        DayLog(dateKey: currentKey)
    }

    private func syncInputFields() {
        if let w = dayLog?.weight {
            weightInput = w.formatted1
        } else {
            weightInput = lastKnownWeight?.formatted1 ?? ""
        }
    }

    private func saveWeight() {
        guard let v = Double(weightInput.replacingOccurrences(of: ",", with: ".")) else { return }
        let log = appState.dayLog(for: currentKey, context: context)
        log.weight = v
        try? context.save()
        hapticSuccess()
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Water Card

private let waterBlue = Color(hex: "5AC8FA")

struct WaterCard: View {
    @Environment(\.modelContext) private var context
    let dateKey: String
    let target: Double

    @Query private var allWater: [WaterEntry]

    private var todayWater: [WaterEntry] {
        allWater.filter { $0.dayKey == dateKey }.sorted { $0.date < $1.date }
    }
    private var total: Double { todayWater.reduce(0) { $0 + $1.liters } }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private func label(for liters: Double) -> String {
        switch liters {
        case 0.2: return "Bicchiere"
        case 0.5: return "Bottiglietta"
        case 1.5: return "Bottiglia"
        default:  return String(format: "%.1f L", liters)
        }
    }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack {
                    SectionLabel(text: "Acqua")
                    Spacer()
                    Text(String(format: "%.1f / %.1f L", total, target))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(total >= target ? waterBlue : .muted)
                }

                // Progress bar — piena larghezza
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 12)
                        Capsule()
                            .fill(waterBlue)
                            .frame(width: geo.size.width * min(total / max(target, 0.01), 1), height: 12)
                    }
                }
                .frame(height: 12)

                // Drink buttons
                HStack(spacing: 8) {
                    WaterBtn(icon: "mug.fill",        label: "Bicchiere",    sub: "0.2 L") { add(0.2) }
                    WaterBtn(icon: "waterbottle.fill", label: "Bottiglietta", sub: "0.5 L") { add(0.5) }
                    WaterBtn(icon: "drop.fill",        label: "Bottiglia",    sub: "1.5 L") { add(1.5) }
                }

                // Entries list (most recent first)
                if !todayWater.isEmpty {
                    Rectangle().fill(Color.brd).frame(height: 0.5).padding(.top, 2)
                    ForEach(todayWater.reversed()) { entry in
                        HStack(spacing: 8) {
                            Text(WaterCard.timeFmt.string(from: entry.date))
                                .font(.system(size: 11)).foregroundColor(.muted)
                                .frame(width: 36, alignment: .leading)
                            Text(label(for: entry.liters))
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.txt)
                            Text("·  \(String(format: "%.1f L", entry.liters))")
                                .font(.system(size: 12)).foregroundColor(.muted)
                            Spacer()
                            Button {
                                context.delete(entry); try? context.save()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold)).foregroundColor(.muted)
                                    .frame(width: 22, height: 22)
                                    .background(Color.card2, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func add(_ liters: Double) {
        context.insert(WaterEntry(dayKey: dateKey, liters: liters))
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct WaterBtn: View {
    let icon: String
    let label: String
    let sub: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(waterBlue)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.txt)
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundColor(.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Triple Ring Card

struct TripleRingCard: View {
    let eaten: Double; let kcalTarget: Double
    let protein: Double; let proteinTarget: Double
    let steps: Int; let stepsTarget: Int
    let burned: Double
    let isFuture: Bool; let appeared: Bool

    private var kcalPct: Double  { eaten / max(kcalTarget, 1) }
    private var protPct: Double  { protein / max(proteinTarget, 1) }
    private var stepsPct: Double { Double(steps) / max(Double(stepsTarget), 1) }

    var body: some View {
        HTCard {
            HStack(spacing: 20) {
                ZStack {
                    ActivityRing(progress: isFuture ? 0 : kcalPct, ringColor: .ringRed,
                                 lineWidth: 14, size: 120, appeared: appeared)
                    ActivityRing(progress: isFuture ? 0 : protPct, ringColor: .ringGreen,
                                 lineWidth: 12, size: 88, appeared: appeared)
                    ActivityRing(progress: isFuture ? 0 : stepsPct, ringColor: .ringBlue,
                                 lineWidth: 10, size: 60, appeared: appeared)
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.ringRed).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Calorie")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                            if isFuture {
                                Text("—").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.muted)
                            } else {
                                Text("\(eaten.formatted0)/\(kcalTarget.formatted0)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(eaten > kcalTarget ? .gymOrange : .ringRed)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Circle().fill(Color.ringGreen).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Proteine")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                            Text("\(protein.formatted0)/\(proteinTarget.formatted0)g")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.ringGreen)
                        }
                    }
                    HStack(spacing: 8) {
                        Circle().fill(Color.ringBlue).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Passi")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                            Text("\(steps.stepsFormatted)/\(stepsTarget.stepsFormatted)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.ringBlue)
                        }
                    }
                    HStack(spacing: 8) {
                        Circle().fill(Color.gymOrange).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Bruciate")
                                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                            Text("\(burned.formatted0) kcal")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.gymOrange)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - SportSectionView

struct SportSectionView: View {
    @Environment(\.modelContext) private var context
    let dateKey: String
    @Binding var showAddSport: Bool
    let onChanged: () -> Void

    @Query private var allSports: [SportEntry]
    private var sports: [SportEntry] { allSports.filter { $0.dayKey == dateKey } }
    private var totalSportKcal: Double { sports.reduce(0) { $0 + $1.kcalBurned } }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Attività fisica")
                    Spacer()
                    if totalSportKcal > 0 {
                        Text("\(totalSportKcal.smartFormat) kcal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.ringGreen)
                    }
                }
                ForEach(sports) { sport in
                    HStack(spacing: 12) {
                        let sportType = SportType.allCases.first { $0.rawValue == sport.sportName }
                        Image(systemName: sportType?.icon ?? "figure.run")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.ringGreen)
                            .frame(width: 32, height: 32)
                            .background(Color.ringGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sport.sportName).font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                            Text("\(sport.durationMinutes) min · \(sport.kcalBurned.smartFormat) kcal")
                                .font(.system(size: 11)).foregroundColor(.muted)
                        }
                        Spacer()
                        Button {
                            context.delete(sport); try? context.save(); onChanged()
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.muted)
                                .frame(width: 24, height: 24).background(Color.card2, in: Circle())
                        }.buttonStyle(.plain)
                    }.padding(.vertical, 4)
                }
                GlassButton(icon: "plus", label: "Aggiungi attività", color: .ringGreen) {
                    showAddSport = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showAddSport) {
            AddSportSheet(dateKey: dateKey, onSaved: onChanged)
        }
    }
}

// MARK: - Add Sport Sheet

struct AddSportSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let dateKey: String; let onSaved: () -> Void

    @State private var selectedSport: SportType?
    @State private var customName = ""; @State private var durationInput = "30"
    @State private var customKcalInput = ""; @State private var useCustom = false

    private var sportName: String { useCustom ? customName : (selectedSport?.rawValue ?? "") }
    private var estimatedKcal: Double {
        let mins = Int(durationInput) ?? 30
        if useCustom { return Double(customKcalInput.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return selectedSport?.estimatedKcal(minutes: mins) ?? 0
    }
    private var isValid: Bool { !sportName.isEmpty && estimatedKcal > 0 }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Picker("Tipo", selection: $useCustom) {
                            Text("Sport predefiniti").tag(false)
                            Text("Personalizzato").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if useCustom {
                            HTCard {
                                VStack(spacing: 12) {
                                    SectionLabel(text: "Nome attività").frame(maxWidth: .infinity, alignment: .leading)
                                    TextField("Es. Paddle", text: $customName)
                                        .foregroundColor(.txt).tint(.acc)
                                        .padding(12)
                                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    NumericField(label: "Durata (min)", value: $durationInput, color: .ringGreen)
                                    NumericField(label: "Kcal bruciate", value: $customKcalInput, color: .gymOrange)
                                }
                            }
                        } else {
                            HTCard {
                                VStack(spacing: 8) {
                                    SectionLabel(text: "Scegli sport").frame(maxWidth: .infinity, alignment: .leading)
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        ForEach(SportType.allCases) { sport in
                                            Button { selectedSport = sport } label: {
                                                VStack(spacing: 6) {
                                                    Image(systemName: sport.icon)
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(selectedSport == sport ? .ringGreen : .muted)
                                                    Text(sport.rawValue)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(selectedSport == sport ? .txt : .muted)
                                                        .lineLimit(1).minimumScaleFactor(0.7)
                                                }
                                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(selectedSport == sport ? Color.ringGreen.opacity(0.12) : Color.card2)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(selectedSport == sport ? Color.ringGreen.opacity(0.4) : .clear, lineWidth: 1.5)
                                                )
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            if selectedSport != nil {
                                HTCard {
                                    VStack(spacing: 12) {
                                        NumericField(label: "Durata (min)", value: $durationInput, color: .ringGreen)
                                        HStack {
                                            Text("Kcal stimate").font(.system(size: 14, weight: .medium)).foregroundColor(.muted)
                                            Spacer()
                                            Text("\(estimatedKcal.smartFormat) kcal")
                                                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.gymOrange)
                                        }
                                    }
                                }
                            }
                        }

                        PillButton(label: "Aggiungi attività", color: .ringGreen, textColor: .black, disabled: !isValid) {
                            save()
                        }
                        .padding(.bottom, 40)
                    }.padding(20)
                }
            )
            .navigationTitle("Attività fisica").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() }.foregroundColor(.muted) } }
        }
        .presentationBackground(Color.bg)
    }

    private func save() {
        let mins = Int(durationInput) ?? 30
        context.insert(SportEntry(dayKey: dateKey, sportName: sportName, durationMinutes: mins, kcalBurned: estimatedKcal))
        try? context.save(); onSaved(); dismiss()
    }
}
