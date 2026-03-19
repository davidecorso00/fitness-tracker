import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @State private var dayLog: DayLog?
    @State private var limits: AppLimits?
    @State private var totals = AppState.DayTotals()
    @State private var weightInput: String = ""
    @State private var stepsInput: String = ""
    @State private var isFuture = false

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    DayNavigator()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 6)

                    VStack(spacing: 14) {
                        // Calorie card
                        if let lim = limits, let log = dayLog {
                            CalorieCard(
                                eaten: totals.kcal,
                                target: lim.kcalTarget,
                                burned: Double(log.burnedKcal),
                                isFuture: isFuture
                            )
                        }

                        // Macro bars
                        if let lim = limits {
                            HTCard {
                                VStack(spacing: 9) {
                                    SectionLabel(text: "Macronutrienti")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    MacroBar(label: "Proteine",    value: totals.protein,      target: lim.proteinTarget,      color: .acc2)
                                    MacroBar(label: "Carboidrati", value: totals.carbs,        target: lim.carbsTarget,        color: .gymBlue)
                                    MacroBar(label: "Grassi",      value: totals.fat,          target: lim.fatTarget,          color: .gymOrange)
                                    Divider().background(Color.brd).padding(.vertical, 2)
                                    MacroBar(label: "Fibre",      value: totals.fiber,        target: lim.fiberTarget,        color: .gymGreen,  small: true)
                                    MacroBar(label: "Zuccheri",   value: totals.sugar,        target: lim.sugarTarget,        color: .gymPink,   small: true)
                                    MacroBar(label: "Gr. saturi", value: totals.saturatedFat, target: lim.saturatedFatTarget, color: .gymOrange, small: true)
                                }
                            }
                        }

                        // Peso + Passi
                        HStack(spacing: 10) {
                            // Peso
                            HTCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    SectionLabel(text: "Peso kg")
                                    HStack(spacing: 8) {
                                        TextField("0.0", text: $weightInput)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(.txt)
                                            .multilineTextAlignment(.center)
                                            .padding(.vertical, 9)
                                            .padding(.horizontal, 12)
                                            .background(Color.brd)
                                            .cornerRadius(12)
                                            .frame(width: 90)
                                        Button("Salva") { saveWeight() }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.acc)
                                            .cornerRadius(12)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            // Passi — inserimento manuale
                            if let lim = limits, let log = dayLog {
                                HTCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        SectionLabel(text: "Passi")
                                        HStack(spacing: 6) {
                                            TextField("0", text: $stepsInput)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundColor(.gymBlue)
                                                .multilineTextAlignment(.center)
                                                .padding(.vertical, 7)
                                                .padding(.horizontal, 8)
                                                .background(Color.brd)
                                                .cornerRadius(10)
                                            Button("OK") { saveSteps() }
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 7)
                                                .padding(.horizontal, 10)
                                                .background(Color.gymBlue)
                                                .cornerRadius(10)
                                        }
                                        .padding(.top, 6)
                                        // Progress bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3).fill(Color.brd).frame(height: 5)
                                                RoundedRectangle(cornerRadius: 3).fill(Color.gymBlue)
                                                    .frame(width: geo.size.width * min(Double(log.steps) / Double(lim.stepsTarget), 1), height: 5)
                                            }
                                        }
                                        .frame(height: 5)
                                        .padding(.top, 6)
                                        Text("/ \(lim.stepsTarget.stepsFormatted)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.muted)
                                            .padding(.top, 4)
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
                                                log.gymColor = gc
                                                try? context.save()
                                                reload()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        )
        .onAppear { reload() }
        .onChange(of: appState.currentDate) { reload() }
    }

    private func reload() {
        let key = appState.currentDateKey
        isFuture = appState.currentDate.isFuture
        dayLog   = appState.dayLog(for: key, context: context)
        limits   = appState.limits(context: context)
        totals   = appState.totals(for: key, context: context)
        weightInput = dayLog?.weight.map { $0.formatted1 } ?? ""
        stepsInput  = dayLog?.steps ?? 0 > 0 ? "\(dayLog!.steps)" : ""
    }

    private func saveWeight() {
        guard let v = Double(weightInput.replacingOccurrences(of: ",", with: ".")) else { return }
        dayLog?.weight = v
        try? context.save()
        dismissKeyboard()
    }

    private func saveSteps() {
        guard let v = Int(stepsInput) else { return }
        dayLog?.steps = v
        try? context.save()
        reload()
        dismissKeyboard()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Day Navigator

struct DayNavigator: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack {
            Button { appState.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.muted)
                    .frame(width: 34, height: 34)
                    .background(Color.card)
                    .cornerRadius(11)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(appState.currentDate.fullDisplay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.txt)
                let badge = appState.currentDate.displayLabel
                if !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.acc2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.acc.opacity(0.15))
                        .cornerRadius(20)
                }
            }

            Spacer()

            Button { appState.goForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.canGoForward ? .muted : .brd)
                    .frame(width: 34, height: 34)
                    .background(Color.card)
                    .cornerRadius(11)
            }
            .buttonStyle(.plain)
            .disabled(!appState.canGoForward)
        }
    }
}

// MARK: - Calorie Card

struct CalorieCard: View {
    let eaten: Double
    let target: Double
    let burned: Double
    let isFuture: Bool

    private var remaining: Double { target - eaten }
    private var isSurplus: Bool   { eaten > target && !isFuture }
    private var pct: Double       { min(eaten / max(target, 1), 1) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2a1060"), Color.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.acc.opacity(0.15))
                .frame(width: 140, height: 140)
                .offset(x: 80, y: -50)

            HStack(spacing: 18) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color.brd, lineWidth: 10)
                        .frame(width: 94, height: 94)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(isSurplus ? Color.gymOrange : Color.acc2,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 94, height: 94)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: pct)
                    VStack(spacing: 1) {
                        Text(isFuture ? "—" : eaten.formatted0)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text("/ \(Int(target))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.muted)
                    }
                }
                .frame(width: 94, height: 94)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isFuture ? "Nessun dato" : isSurplus ? "Surplus" : "Rimanenti")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.muted)

                    if isFuture {
                        Text("—")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.muted)
                    } else if isSurplus {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text((eaten - target).formatted0)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.gymOrange)
                            Text("kcal")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gymOrange.opacity(0.7))
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(remaining.formatted0)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.txt)
                            Text("kcal")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.muted)
                        }
                    }

                    if !isFuture {
                        HStack(spacing: 6) {
                            Text("🔥")
                                .font(.system(size: 16))
                            Text(burned.formatted0)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.gymOrange)
                            Text("kcal bruciate")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.muted)
                        }
                        .padding(.top, 8)
                        .overlay(alignment: .top) {
                            Divider().background(Color.white.opacity(0.08)).offset(y: 8)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .cornerRadius(22)
    }
}
