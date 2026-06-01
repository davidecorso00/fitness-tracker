import SwiftUI
import SwiftData

struct NutritionalGoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Query private var allLimits: [AppLimits]

    private var lim: AppLimits? { allLimits.first }

    @State private var kcalStr = ""
    @State private var usePercent = false
    @State private var carbsStr = ""
    @State private var proteinStr = ""
    @State private var fatStr = ""
    @State private var sugarStr = ""
    @State private var satFatStr = ""
    @State private var saltStr = ""
    @State private var fiberStr = ""

    // MARK: - Derived values

    private func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var kcal: Double { parse(kcalStr) }
    private var carbsVal: Double { parse(carbsStr) }
    private var proteinVal: Double { parse(proteinStr) }
    private var fatVal: Double { parse(fatStr) }
    private var sugarVal: Double { parse(sugarStr) }
    private var satFatVal: Double { parse(satFatStr) }

    private var carbsGrams: Double { usePercent ? carbsVal * kcal / 400 : carbsVal }
    private var proteinGrams: Double { usePercent ? proteinVal * kcal / 400 : proteinVal }
    private var fatGrams: Double { usePercent ? fatVal * kcal / 900 : fatVal }

    private var macroWarning: String? {
        if usePercent {
            let sum = carbsVal + proteinVal + fatVal
            guard sum > 0 else { return nil }
            if abs(sum - 100) > 0.5 {
                return "Somma: \(sum.formatted1)% — deve essere 100%"
            }
        } else {
            let computed = carbsVal * 4 + proteinVal * 4 + fatVal * 9
            guard computed > 0 else { return nil }
            if abs(computed - kcal) > 10 {
                return "Kcal dai macro: \(Int(computed)) — target: \(Int(kcal)) kcal"
            }
        }
        return nil
    }

    private var sugarError: Bool {
        sugarVal > 0 && carbsGrams > 0 && sugarVal > carbsGrams
    }
    private var satFatError: Bool {
        satFatVal > 0 && fatGrams > 0 && satFatVal > fatGrams
    }
    private var canSave: Bool {
        kcal > 0 && macroWarning == nil && !sugarError && !satFatError
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        kcalCard
                        modeCard
                        macrosCard
                        absCard
                        warningsSection
                        PillButton(label: "Conferma", disabled: !canSave) { saveAndDismiss() }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            )
            .navigationTitle("Obiettivi nutrizionali")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { hideKeyboard() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { loadFromLimits() }
    }

    // MARK: - Sub-views

    private var kcalCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Calorie target").frame(maxWidth: .infinity, alignment: .leading)
                BigInputField(placeholder: "0", value: $kcalStr, keyboardType: .numberPad)
                Text("kcal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var modeCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Modalità macro").frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $usePercent) {
                    Text("Grammi").tag(false)
                    Text("Percentuale").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: usePercent) { _, newVal in
                    withAnimation(.spring(response: 0.3)) { toggleMode(toPercent: newVal) }
                }
            }
        }
    }

    private var macrosCard: some View {
        HTCard {
            VStack(spacing: 14) {
                macroRow(label: "Carboidrati", str: $carbsStr, unit: usePercent ? "%" : "g", color: .gymBlue)
                subRow(label: "di cui Zuccheri", str: $sugarStr, error: sugarError)

                Divider().overlay(Color.brd)

                macroRow(label: "Proteine", str: $proteinStr, unit: usePercent ? "%" : "g", color: .ringGreen)

                Divider().overlay(Color.brd)

                macroRow(label: "Grassi", str: $fatStr, unit: usePercent ? "%" : "g", color: .gymOrange)
                subRow(label: "di cui Saturi", str: $satFatStr, error: satFatError)
            }
        }
    }

    private var absCard: some View {
        HTCard {
            VStack(spacing: 14) {
                macroRow(label: "Sale", str: $saltStr, unit: "g", color: .muted)
                Divider().overlay(Color.brd)
                macroRow(label: "Fibre", str: $fiberStr, unit: "g", color: .gymCyan)
            }
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        if let warning = macroWarning {
            warningBanner(warning)
        }
        if sugarError {
            warningBanner("Zuccheri (\(sugarStr)g) superiori ai carboidrati totali (\(carbsGrams.smartFormat)g)")
        }
        if satFatError {
            warningBanner("Grassi saturi (\(satFatStr)g) superiori ai grassi totali (\(fatGrams.smartFormat)g)")
        }
    }

    // MARK: - Row builders

    private func macroRow(label: String, str: Binding<String>, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.txt)
            Spacer()
            HStack(spacing: 6) {
                TextField("0", text: str)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color).tint(color)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                Text(unit)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.muted)
                    .frame(width: 16, alignment: .leading)
            }
        }
    }

    private func subRow(label: String, str: Binding<String>, error: Bool) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10)).foregroundColor(.muted)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                TextField("0", text: str)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(error ? .gymOrange : .white.opacity(0.7))
                    .tint(error ? .gymOrange : .acc)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(
                        (error ? Color.gymOrange : Color.white).opacity(error ? 0.1 : 0.07),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                Text("g")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.muted)
                    .frame(width: 16, alignment: .leading)
            }
        }
        .padding(.leading, 16)
    }

    private func warningBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13)).foregroundColor(.gymOrange)
            Text(msg)
                .font(.system(size: 13, weight: .medium)).foregroundColor(.gymOrange)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gymOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Logic

    private func loadFromLimits() {
        guard let l = lim else { return }
        kcalStr = l.kcalTarget.smartFormat
        let useP = l.macroInputMode == "percent"
        usePercent = useP
        if useP && l.kcalTarget > 0 {
            let k = l.kcalTarget
            carbsStr = (l.carbsTarget * 4 / k * 100).formatted1
            proteinStr = (l.proteinTarget * 4 / k * 100).formatted1
            fatStr = (l.fatTarget * 9 / k * 100).formatted1
        } else {
            carbsStr = l.carbsTarget.smartFormat
            proteinStr = l.proteinTarget.smartFormat
            fatStr = l.fatTarget.smartFormat
        }
        sugarStr = l.sugarTarget.smartFormat
        satFatStr = l.saturatedFatTarget.smartFormat
        saltStr = l.saltTarget.smartFormat
        fiberStr = l.fiberTarget.smartFormat
    }

    private func toggleMode(toPercent: Bool) {
        let k = parse(kcalStr)
        if toPercent {
            let c = parse(carbsStr), p = parse(proteinStr), f = parse(fatStr)
            carbsStr = k > 0 ? (c * 4 / k * 100).formatted1 : "0"
            proteinStr = k > 0 ? (p * 4 / k * 100).formatted1 : "0"
            fatStr = k > 0 ? (f * 9 / k * 100).formatted1 : "0"
        } else {
            let c = parse(carbsStr), p = parse(proteinStr), f = parse(fatStr)
            carbsStr = k > 0 ? (c * k / 400).formatted1 : "0"
            proteinStr = k > 0 ? (p * k / 400).formatted1 : "0"
            fatStr = k > 0 ? (f * k / 900).formatted1 : "0"
        }
    }

    private func saveAndDismiss() {
        guard let l = lim, canSave else { return }
        l.kcalTarget = kcal
        l.carbsTarget = carbsGrams
        l.proteinTarget = proteinGrams
        l.fatTarget = fatGrams
        l.sugarTarget = sugarVal
        l.saturatedFatTarget = satFatVal
        l.saltTarget = parse(saltStr)
        l.fiberTarget = parse(fiberStr)
        l.macroInputMode = usePercent ? "percent" : "grams"
        try? context.save()
        appState.saveTargetHistory(from: l, context: context)
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
