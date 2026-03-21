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

    // Streak: giorni consecutivi in deficit fino a ieri
    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]
    @Query private var allSports: [SportEntry]

    private var deficitStreak: Int {
        guard let lim = limits else { return 0 }
        var streak = 0
        // Parte da oggi (non ieri) così si vede subito il giorno corrente
        var date = Calendar.current.startOfDay(for: Date())
        for _ in 0..<365 {
            let key = date.dateKey
            let eaten = allEntries.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalSnapshot }
            // Salta giorni futuri o senza dati
            guard eaten > 0 else {
                // Se è oggi senza dati ancora, vai a ieri e continua
                if date.isToday { date = date.adding(days: -1); continue }
                break
            }
            let burned = Double(allLogs.first { $0.dateKey == key }?.burnedKcal ?? 0)
                + allSports.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalBurned }
            let inDeficit = eaten < lim.kcalTarget + burned
            if inDeficit { streak += 1 } else { break }
            date = date.adding(days: -1)
        }
        return streak
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header con nav giorni + gear
                    HStack {
                        Button { appState.goBack() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.muted)
                                .frame(width: 34, height: 34).background(Color.card).cornerRadius(11)
                        }.buttonStyle(.plain)

                        Spacer()

                        VStack(spacing: 3) {
                            Text(appState.currentDate.fullDisplay)
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                            let badge = appState.currentDate.displayLabel
                            if !badge.isEmpty {
                                Text(badge).font(.system(size: 10, weight: .bold)).foregroundColor(.acc2)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Color.acc.opacity(0.15)).cornerRadius(20)
                            }
                        }

                        Spacer()

                        Button { appState.goForward() } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(appState.canGoForward ? .muted : .brd)
                                .frame(width: 34, height: 34).background(Color.card).cornerRadius(11)
                        }.buttonStyle(.plain).disabled(!appState.canGoForward)

                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .medium)).foregroundColor(.muted)
                                .frame(width: 34, height: 34).background(Color.card).cornerRadius(11)
                        }.buttonStyle(.plain).padding(.leading, 6)
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 10)

                    VStack(spacing: 14) {
                        // Streak deficit
                        if deficitStreak > 0 {
                            HStack(spacing: 10) {
                                Text("🔥").font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(deficitStreak) giorni in deficit")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                                    Text("Stai mantenendo il deficit consecutivo")
                                        .font(.system(size: 12)).foregroundColor(.muted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                LinearGradient(colors: [Color.gymOrange.opacity(0.2), Color.acc.opacity(0.1)],
                                    startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }

                        // Calorie card
                        if let lim = limits, let log = dayLog {
                            CalorieCard(eaten: totals.kcal, target: lim.kcalTarget,
                                burned: Double(log.burnedKcal) + sportBurned, isFuture: isFuture)
                        }

                        // Macro bars
                        if let lim = limits {
                            HTCard {
                                VStack(spacing: 9) {
                                    SectionLabel(text: "Macronutrienti").frame(maxWidth: .infinity, alignment: .leading)
                                    MacroBar(label: "Proteine",    value: totals.protein,      target: lim.proteinTarget,      color: .acc2)
                                    MacroBar(label: "Carboidrati", value: totals.carbs,        target: lim.carbsTarget,        color: .gymBlue)
                                    MacroBar(label: "Grassi",      value: totals.fat,          target: lim.fatTarget,          color: .gymOrange)
                                    Divider().background(Color.brd).padding(.vertical, 2)
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
                                VStack(alignment: .leading, spacing: 4) {
                                    SectionLabel(text: "Peso kg")
                                    HStack(spacing: 8) {
                                        TextField("0.0", text: $weightInput)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.txt).multilineTextAlignment(.center)
                                            .padding(.vertical, 9).padding(.horizontal, 12)
                                            .background(Color.brd).cornerRadius(12).frame(width: 90)
                                        Button("Salva") { saveWeight() }
                                            .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(Color.acc).cornerRadius(12)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            if let lim = limits, let log = dayLog {
                                HTCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        SectionLabel(text: "Passi")
                                        HStack(spacing: 6) {
                                            TextField("0", text: $stepsInput).keyboardType(.numberPad)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundColor(.gymBlue).multilineTextAlignment(.center)
                                                .padding(.vertical, 7).padding(.horizontal, 8)
                                                .background(Color.brd).cornerRadius(10)
                                            Button("OK") { saveSteps() }
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                                .padding(.vertical, 7).padding(.horizontal, 10)
                                                .background(Color.gymBlue).cornerRadius(10)
                                        }
                                        .padding(.top, 6)
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3).fill(Color.brd).frame(height: 5)
                                                RoundedRectangle(cornerRadius: 3).fill(Color.gymBlue)
                                                    .frame(width: geo.size.width * min(Double(log.steps) / Double(lim.stepsTarget), 1), height: 5)
                                            }
                                        }
                                        .frame(height: 5).padding(.top, 6)
                                        Text("/ \(lim.stepsTarget.stepsFormatted)")
                                            .font(.system(size: 10, weight: .semibold)).foregroundColor(.muted).padding(.top, 4)
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

                        // Sport / Attività fisica
                        SportSectionView(
                            dateKey: appState.currentDateKey,
                            showAddSport: $showAddSport,
                            onChanged: { reload() }
                        )
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
        )
        .onAppear { reload() }
        .onChange(of: appState.currentDate) { reload() }
    }

    private func reload() {
        let key = appState.currentDateKey
        isFuture = appState.currentDate.isFuture
        dayLog  = appState.dayLog(for: key, context: context)
        limits  = appState.limits(context: context)
        totals  = appState.totals(for: key, context: context)
        sportBurned = appState.sportKcal(for: key, context: context)
        weightInput = dayLog?.weight.map { $0.formatted1 } ?? ""
        stepsInput  = (dayLog?.steps ?? 0) > 0 ? "\(dayLog!.steps)" : ""
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

// MARK: - Calorie Card

struct CalorieCard: View {
    let eaten: Double; let target: Double; let burned: Double; let isFuture: Bool
    private var remaining: Double { target - eaten }
    private var isSurplus: Bool   { eaten > target && !isFuture }
    private var pct: Double       { min(eaten / max(target, 1), 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2a1060"), Color.card],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.acc.opacity(0.15)).frame(width: 140, height: 140).offset(x: 80, y: -50)
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.brd, lineWidth: 10).frame(width: 94, height: 94)
                    Circle().trim(from: 0, to: pct)
                        .stroke(isSurplus ? Color.gymOrange : Color.acc2,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 94, height: 94).rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: pct)
                    VStack(spacing: 1) {
                        Text(isFuture ? "—" : eaten.formatted0)
                            .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
                        Text("/ \(Int(target))").font(.system(size: 9, weight: .medium)).foregroundColor(.muted)
                    }
                }
                .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isFuture ? "Nessun dato" : isSurplus ? "Surplus" : "Rimanenti")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
                    if isFuture {
                        Text("—").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.muted)
                    } else if isSurplus {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text((eaten - target).formatted0)
                                .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.gymOrange)
                            Text("kcal").font(.system(size: 13, weight: .medium)).foregroundColor(.gymOrange.opacity(0.7))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(remaining.formatted0)
                                .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.txt)
                            Text("kcal").font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                        }
                    }
                    if !isFuture {
                        HStack(spacing: 6) {
                            Text("🔥").font(.system(size: 16))
                            Text(burned.formatted0)
                                .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.gymOrange)
                            Text("kcal bruciate").font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
                        }
                        .padding(.top, 8)
                        .overlay(alignment: .top) { Divider().background(Color.white.opacity(0.08)).offset(y: 8) }
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .cornerRadius(22)
    }
}

// MARK: - Sport Section

struct SportSectionView: View {
    @Environment(\.modelContext) private var context
    let dateKey: String
    @Binding var showAddSport: Bool
    let onChanged: () -> Void

    @Query private var allSports: [SportEntry]

    private var sports: [SportEntry] {
        allSports.filter { $0.dayKey == dateKey }
    }
    private var totalSportKcal: Double {
        sports.reduce(0) { $0 + $1.kcalBurned }
    }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Attività fisica")
                    Spacer()
                    if totalSportKcal > 0 {
                        Text("\(totalSportKcal.smartFormat) kcal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.gymGreen)
                    }
                }

                ForEach(sports) { sport in
                    HStack(spacing: 12) {
                        // Trova icona dallo SportType se match
                        let sportType = SportType.allCases.first { $0.rawValue == sport.sportName }
                        Image(systemName: sportType?.icon ?? "figure.run")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gymGreen)
                            .frame(width: 32, height: 32)
                            .background(Color.gymGreen.opacity(0.15))
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sport.sportName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "dddddd"))
                            Text("\(sport.durationMinutes) min · \(sport.kcalBurned.smartFormat) kcal")
                                .font(.system(size: 11)).foregroundColor(.muted)
                        }
                        Spacer()
                        Button {
                            context.delete(sport)
                            try? context.save()
                            onChanged()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.muted)
                                .frame(width: 24, height: 24)
                                .background(Color.brd).cornerRadius(8)
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                Button { showAddSport = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("Aggiungi attività").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.gymGreen)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.gymGreen.opacity(0.1)).cornerRadius(12)
                }
                .buttonStyle(.plain)
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

    let dateKey: String
    let onSaved: () -> Void

    @State private var selectedSport: SportType?
    @State private var customName = ""
    @State private var durationInput = "30"
    @State private var customKcalInput = ""
    @State private var useCustom = false

    private var sportName: String {
        useCustom ? customName : (selectedSport?.rawValue ?? "")
    }

    private var estimatedKcal: Double {
        let mins = Int(durationInput) ?? 30
        if useCustom {
            return Double(customKcalInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        return selectedSport?.estimatedKcal(minutes: mins) ?? 0
    }

    private var isValid: Bool {
        !sportName.isEmpty && estimatedKcal > 0
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Toggle custom / predefined
                        HStack(spacing: 0) {
                            Button { useCustom = false } label: {
                                Text("Sport predefiniti")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(!useCustom ? .white : .muted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(!useCustom ? Color.acc : Color.clear).cornerRadius(10)
                            }.buttonStyle(.plain)
                            Button { useCustom = true } label: {
                                Text("Personalizzato")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(useCustom ? .white : .muted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(useCustom ? Color.acc : Color.clear).cornerRadius(10)
                            }.buttonStyle(.plain)
                        }
                        .padding(4).background(Color.card).cornerRadius(14)

                        if useCustom {
                            HTCard {
                                VStack(spacing: 12) {
                                    SectionLabel(text: "Nome attività").frame(maxWidth: .infinity, alignment: .leading)
                                    TextField("Es. Paddle", text: $customName)
                                        .foregroundColor(.txt).tint(.acc2)
                                        .padding(12).background(Color.brd).cornerRadius(12)
                                    NumericField(label: "Durata (min)", value: $durationInput, color: .gymGreen)
                                    NumericField(label: "Kcal bruciate", value: $customKcalInput, color: .gymOrange)
                                }
                            }
                        } else {
                            HTCard {
                                VStack(spacing: 8) {
                                    SectionLabel(text: "Scegli sport").frame(maxWidth: .infinity, alignment: .leading)
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                                    ], spacing: 8) {
                                        ForEach(SportType.allCases) { sport in
                                            Button {
                                                selectedSport = sport
                                            } label: {
                                                VStack(spacing: 6) {
                                                    Image(systemName: sport.icon)
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundColor(selectedSport == sport ? .gymGreen : .muted)
                                                    Text(sport.rawValue)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(selectedSport == sport ? .txt : .muted)
                                                        .lineLimit(1).minimumScaleFactor(0.7)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(selectedSport == sport ? Color.gymGreen.opacity(0.15) : Color.brd)
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedSport == sport ? Color.gymGreen.opacity(0.5) : .clear, lineWidth: 1.5)
                                                )
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            if selectedSport != nil {
                                HTCard {
                                    VStack(spacing: 12) {
                                        NumericField(label: "Durata (min)", value: $durationInput, color: .gymGreen)
                                        HStack {
                                            Text("Kcal stimate")
                                                .font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "cccccc"))
                                            Spacer()
                                            Text("\(estimatedKcal.smartFormat) kcal")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.gymOrange)
                                        }
                                    }
                                }
                            }
                        }

                        Button { save() } label: {
                            Text("Aggiungi attività")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(isValid ? Color.gymGreen : Color.brd).cornerRadius(16)
                        }
                        .buttonStyle(.plain).disabled(!isValid).padding(.bottom, 40)
                    }
                    .padding(20)
                }
            )
            .navigationTitle("Attività fisica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
    }

    private func save() {
        let mins = Int(durationInput) ?? 30
        let kcal = estimatedKcal
        let entry = SportEntry(dayKey: dateKey, sportName: sportName,
                               durationMinutes: mins, kcalBurned: kcal)
        context.insert(entry)
        try? context.save()
        onSaved()
        dismiss()
    }
}
