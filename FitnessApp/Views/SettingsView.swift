import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var limits: AppLimits?
    @State private var profile: UserProfile?
    @State private var todayLog: DayLog?
    @State private var editing: LimitField?
    @State private var showNutritionGoals = false

    @Query(sort: \DayLog.dateKey, order: .reverse) private var allLogs: [DayLog]

    /// Peso più recente inserito in qualsiasi giorno fino ad oggi.
    private var lastKnownWeight: Double? {
        let todayKey = Date().dateKey
        return allLogs.first { $0.dateKey <= todayKey && $0.weight != nil }?.weight
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // ── Profilo utente ──────────────────────────────────
                        if let prof = profile {
                            LimitGroup(title: "Profilo") {
                                // Peso: legge il peso di oggi o l'ultimo registrato
                                let weightValue = todayLog?.weight ?? lastKnownWeight ?? 0
                                LimitRow(label: "Peso attuale", value: weightValue, unit: "kg") {
                                    editing = LimitField(label: "Peso attuale", unit: "kg", current: weightValue) { val in
                                        let log = appState.dayLog(for: Date().dateKey, context: context)
                                        log.weight = val
                                        try? context.save()
                                        todayLog = log
                                    }
                                }
                                LimitRow(label: "Altezza", value: prof.heightCm ?? 0, unit: "cm") {
                                    editing = LimitField(label: "Altezza", unit: "cm", current: prof.heightCm ?? 0) {
                                        prof.heightCm = $0; save()
                                    }
                                }
                                // Sesso
                                HStack {
                                    Text("Sesso")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "cccccc"))
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { prof.sex },
                                        set: { prof.sex = $0; save() }
                                    )) {
                                        ForEach(Sex.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }
                                    .labelsHidden()
                                    .tint(.acc2)
                                }
                                .padding(.horizontal, 18).padding(.vertical, 13)
                                .overlay(alignment: .top) {
                                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5).padding(.leading, 18)
                                }
                                // Data di nascita
                                HStack {
                                    Text("Data di nascita")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "cccccc"))
                                    Spacer()
                                    DatePicker("", selection: Binding(
                                        get: { prof.birthDate ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())! },
                                        set: { prof.birthDate = $0; save() }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.acc2)
                                }
                                .padding(.horizontal, 18).padding(.vertical, 13)
                                .overlay(alignment: .top) {
                                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5).padding(.leading, 18)
                                }
                            }
                        }

                        // ── Target nutrizionali ─────────────────────────────
                        if let lim = limits {
                            Button { showNutritionGoals = true } label: {
                                VStack(spacing: 0) {
                                    HStack {
                                        SectionLabel(text: "Obiettivi nutrizionali")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color(hex: "444444"))
                                    }
                                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

                                    HStack(spacing: 0) {
                                        macroSummaryItem(label: "Kcal", value: lim.kcalTarget.formatted0, color: .ringRed)
                                        Rectangle().fill(Color.brd).frame(width: 0.5, height: 32)
                                        macroSummaryItem(label: "Proteine", value: "\(lim.proteinTarget.smartFormat)g", color: .ringGreen)
                                        Rectangle().fill(Color.brd).frame(width: 0.5, height: 32)
                                        macroSummaryItem(label: "Carbo", value: "\(lim.carbsTarget.smartFormat)g", color: .gymBlue)
                                        Rectangle().fill(Color.brd).frame(width: 0.5, height: 32)
                                        macroSummaryItem(label: "Grassi", value: "\(lim.fatTarget.smartFormat)g", color: .gymOrange)
                                    }
                                    .padding(.horizontal, 18).padding(.bottom, 14)
                                }
                                .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)

                            LimitGroup(title: "Attività & Obiettivi") {
                                LimitRow(label: "Passi giornalieri", value: Double(lim.stepsTarget), unit: "") {
                                    editing = LimitField(label: "Passi", unit: "", current: Double(lim.stepsTarget), isInt: true) { lim.stepsTarget = Int($0); save() }
                                }
                                LimitRow(label: "Acqua", value: lim.waterTarget, unit: "L", last: true) {
                                    editing = LimitField(label: "Acqua", unit: "L", current: lim.waterTarget) { lim.waterTarget = $0; save() }
                                }
                            }
                            LimitGroup(title: "Obiettivo peso") {
                                LimitRow(label: "Peso obiettivo", value: lim.targetWeight, unit: "kg") {
                                    editing = LimitField(label: "Peso obiettivo", unit: "kg", current: lim.targetWeight) { lim.targetWeight = $0; save() }
                                }
                                HStack {
                                    Text("Data obiettivo")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "cccccc"))
                                    Spacer()
                                    if lim.targetDate != nil {
                                        DatePicker("", selection: Binding(
                                            get: { lim.targetDate ?? Date().adding(days: 90) },
                                            set: { lim.targetDate = $0; save() }
                                        ), in: Date()..., displayedComponents: .date)
                                        .labelsHidden().colorScheme(.dark).tint(.acc2)
                                        Button {
                                            lim.targetDate = nil; save()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.muted)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Button("Aggiungi") {
                                            lim.targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
                                            save()
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

                            BackupView()
                                .padding(.horizontal, -20)
                                .padding(.top, 8)

                            // Data inizio tracciamento
                            VStack(spacing: 0) {
                                SectionLabel(text: "Tracciamento risultati")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
                                HStack {
                                    Text("Data inizio")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "cccccc"))
                                    Spacer()
                                    DatePicker("", selection: Binding(
                                        get: { lim.startDate },
                                        set: { lim.startDate = $0; save() }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.acc2)
                                }
                                .padding(.horizontal, 18).padding(.vertical, 13)
                            }
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            )
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear {
            limits   = appState.limits(context: context)
            profile  = appState.userProfile(context: context)
            todayLog = appState.dayLog(for: Date().dateKey, context: context)
        }
        .sheet(isPresented: $showNutritionGoals) { NutritionalGoalsView() }
        .sheet(item: $editing) { LimitEditSheet(field: $0) }
    }

    private func save() {
        try? context.save()
        if let lim = limits {
            appState.saveTargetHistory(from: lim, context: context)
        }
    }

    @ViewBuilder
    private func macroSummaryItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable limit components

struct LimitGroup<Content: View>: View {
    let title: String; let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) {
            SectionLabel(text: title).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            content
        }
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
}

struct LimitRow: View {
    let label: String; let value: Double; let unit: String
    var last: Bool = false; let onTap: () -> Void
    var displayValue: String {
        if unit == "" { return "\(Int(value))" }
        let numStr = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : value.formatted1
        return "\(numStr) \(unit)"
    }
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(Color(hex: "cccccc"))
                Spacer()
                Text(displayValue).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.acc2)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "444444"))
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .overlay(alignment: .top) {
                if !last { Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5).padding(.leading, 18) }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LimitField: Identifiable {
    let id = UUID(); let label: String; let unit: String; let current: Double
    var isInt: Bool = false; let onSave: (Double) -> Void
}

struct LimitEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let field: LimitField
    @State private var input = ""
    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(field.label).font(.system(size: 18, weight: .bold)).foregroundColor(.txt)
                        if !field.unit.isEmpty { Text(field.unit).font(.system(size: 14)).foregroundColor(.muted) }
                    }
                    BigInputField(placeholder: "0", value: $input, keyboardType: field.isInt ? .numberPad : .decimalPad)
                        .frame(maxWidth: 220)
                    PillButton(label: "Salva") {
                        let raw = input.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(raw) { field.onSave(v) }
                        dismiss()
                    }
                    .frame(maxWidth: 220)
                    Spacer()
                }
            )
            .navigationTitle("Modifica").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationDetents([.medium]).presentationBackground(Color.bg)
        .onAppear { input = field.isInt ? "\(Int(field.current))" : field.current.formatted1 }
    }
}
