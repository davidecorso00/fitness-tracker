import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Binding var showSettings: Bool

    @State private var dayLog: DayLog?
    @State private var limits: AppLimits?
    @State private var totals = AppState.DayTotals()
    @State private var weightInput: String = ""
    @State private var stepsInput: String = ""
    @State private var isFuture = false
    @State private var sportBurned: Double = 0
    @State private var showAddSport = false
    @State private var appeared = false

    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]

    private var deficitStreak: Int {
        guard let lim = limits else { return 0 }
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        for _ in 0..<365 {
            let key = date.dateKey
            let eaten = allEntries.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalSnapshot }
            guard eaten > 0 else {
                if date.isToday { date = date.adding(days: -1); continue }
                break
            }
            let burned = Double(allLogs.first { $0.dateKey == key }?.burnedKcal ?? 0)
                + allSports.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalBurned }
            if eaten < lim.kcalTarget + burned { streak += 1 } else { break }
            date = date.adding(days: -1)
        }
        return streak
    }

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

                        // TRIPLE RING CARD (Apple Fitness style)
                        if let lim = limits, let log = dayLog {
                            let totalBurned = Double(log.burnedKcal) + sportBurned
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
                                    MacroBar(label: "Sale",       value: totals.salt,          target: lim.saltTarget,          color: .muted,     small: true)
                                }
                            }
                        }

                        // Peso + Passi
                        HStack(spacing: 10) {
                            HTCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    SectionLabel(text: "Peso kg")
                                    BigInputField(placeholder: "0.0", value: $weightInput, color: .txt, fontSize: 22)
                                    PillButton(label: "Salva", color: .acc, textColor: .black) {
                                        saveWeight()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)

                            if let lim = limits, let log = dayLog {
                                HTCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        SectionLabel(text: "Passi")
                                        BigInputField(placeholder: "0", value: $stepsInput, color: .ringBlue, keyboardType: .numberPad, fontSize: 22)
                                        PillButton(label: "OK", color: .gymBlue, textColor: .white) {
                                            saveSteps()
                                        }
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
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Palestra
                        if let log = dayLog {
                            HTCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel(text: "Palestra oggi")
                                    if #available(iOS 26.0, *) {
                                        GlassEffectContainer {
                                            HStack(spacing: 10) {
                                                ForEach(GymColor.allCases, id: \.self) { gc in
                                                    GymDot(gymColor: gc, isSelected: log.gymColor == gc) {
                                                        log.gymColor = gc; try? context.save(); reload()
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 10) {
                                            ForEach(GymColor.allCases, id: \.self) { gc in
                                                GymDot(gymColor: gc, isSelected: log.gymColor == gc) {
                                                    log.gymColor = gc; try? context.save(); reload()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Sport
                        SportSectionView(dateKey: appState.currentDateKey,
                                         showAddSport: $showAddSport, onChanged: { reload() })
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
        )
        .onAppear { reload(); withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appeared = true } }
        .onChange(of: appState.currentDate) { appeared = false; reload()
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) { appeared = true }
        }
    }

    private func reload() {
        let key = appState.currentDateKey
        isFuture = appState.currentDate.isFuture
        dayLog = appState.dayLog(for: key, context: context)
        limits = appState.limits(context: context)
        totals = appState.totals(for: key, context: context)
        sportBurned = appState.sportKcal(for: key, context: context)
        weightInput = dayLog?.weight.map { $0.formatted1 } ?? ""
        stepsInput = (dayLog?.steps ?? 0) > 0 ? "\(dayLog!.steps)" : ""
    }
    private func saveWeight() {
        guard let v = Double(weightInput.replacingOccurrences(of: ",", with: ".")) else { return }
        dayLog?.weight = v; try? context.save(); dismissKeyboard()
    }
    private func saveSteps() {
        guard let v = Int(stepsInput) else { return }
        dayLog?.steps = v; try? context.save(); reload(); dismissKeyboard()
    }
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Triple Ring Card (Apple Fitness)

struct TripleRingCard: View {
    let eaten: Double; let kcalTarget: Double
    let protein: Double; let proteinTarget: Double
    let steps: Int; let stepsTarget: Int
    let burned: Double
    let isFuture: Bool; let appeared: Bool

    private var kcalPct: Double { eaten / max(kcalTarget, 1) }
    private var protPct: Double { protein / max(proteinTarget, 1) }
    private var stepsPct: Double { Double(steps) / max(Double(stepsTarget), 1) }
    private var remaining: Double { kcalTarget - eaten }

    var body: some View {
        HTCard {
            HStack(spacing: 20) {
                // Triple rings
                ZStack {
                    ActivityRing(progress: isFuture ? 0 : kcalPct, ringColor: .ringRed,
                                 lineWidth: 14, size: 120, appeared: appeared)
                    ActivityRing(progress: isFuture ? 0 : protPct, ringColor: .ringGreen,
                                 lineWidth: 12, size: 88, appeared: appeared)
                    ActivityRing(progress: isFuture ? 0 : stepsPct, ringColor: .ringBlue,
                                 lineWidth: 10, size: 60, appeared: appeared)
                }
                .frame(width: 120, height: 120)

                // Stats
                VStack(alignment: .leading, spacing: 10) {
                    // Calorie
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
                    // Proteine
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
                    // Passi
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
                    // Bruciate
                    if !isFuture && burned > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11)).foregroundColor(.gymOrange)
                            Text("\(burned.formatted0) bruciate")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gymOrange)
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Sport Section

struct SportSectionView: View {
    @Environment(\.modelContext) private var context
    let dateKey: String; @Binding var showAddSport: Bool; let onChanged: () -> Void

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
                        // Toggle
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
