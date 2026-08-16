import SwiftUI

// Quali dischi caricare per arrivare al peso voluto. Si apre dalla scheda
// esercizio durante l'allenamento, già impostato sul carico della serie.

struct PlateCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialWeight: Double

    @AppStorage("plateCalcBar") private var barRaw: Double = BarWeight.olympic20.rawValue
    @State private var weightInput: String = ""

    private var bar: BarWeight { BarWeight(rawValue: barRaw) ?? .olympic20 }
    private var target: Double {
        Double(weightInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var load: PlateLoad { plateLoad(target: target, bar: bar.rawValue) }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        targetCard
                        barCard
                        if target > 0 { resultCard }
                    }
                    .padding(20)
                }
            )
            .navigationTitle("Calcolo dischi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.acc2)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear {
            if weightInput.isEmpty, initialWeight > 0 { weightInput = initialWeight.clean }
        }
    }

    private var targetCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Peso obiettivo")
                HStack(spacing: 10) {
                    BigInputField(placeholder: "0", value: $weightInput, color: .gymBlue, fontSize: 26)
                    Text("kg")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.muted)
                    Button { adjust(-weightStep(for: target, isBarbell: bar != .none)) } label: {
                        stepIcon("minus")
                    }
                    .buttonStyle(.plain)
                    Button { adjust(weightStep(for: target, isBarbell: bar != .none)) } label: {
                        stepIcon("plus")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stepIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .bold)).foregroundColor(.txt)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.08), in: Circle())
    }

    private var barCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Bilanciere")
                Picker("", selection: $barRaw) {
                    ForEach(BarWeight.allCases) { b in
                        Text(b == .none ? "Nessuno" : "\(Int(b.rawValue)) kg").tag(b.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Text(bar.label)
                    .font(.system(size: 11)).foregroundColor(.muted)
            }
        }
    }

    private var resultCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Per lato")

                if load.perSide.isEmpty {
                    Text(target < bar.rawValue
                         ? "Il bilanciere da solo pesa già \(bar.rawValue.clean) kg"
                         : "Solo bilanciere")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.muted)
                } else {
                    // I dischi, disegnati in scala
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(load.perSide.enumerated()), id: \.offset) { _, plate in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plateColor(plate))
                                    .frame(width: 20, height: plateHeight(plate))
                                Text(plate.clean)
                                    .font(.system(size: 9, weight: .bold)).foregroundColor(.muted)
                            }
                        }
                        Spacer()
                    }
                    .frame(height: 96, alignment: .bottom)

                    Text(plateSummary(load.perSide))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.gymBlue)
                }

                Rectangle().fill(Color.brd).frame(height: 0.5)

                HStack {
                    Text("Totale caricato")
                        .font(.system(size: 13)).foregroundColor(.muted)
                    Spacer()
                    Text("\(load.achieved.clean) kg")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(load.isExact ? .gymGreen : .gymOrange)
                }

                if !load.isExact {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.gymOrange)
                        Text(load.difference > 0
                             ? "Mancano \(load.difference.clean) kg: non ci sono dischi abbastanza piccoli"
                             : "Il bilanciere supera già il peso richiesto")
                            .font(.system(size: 12)).foregroundColor(.gymOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func adjust(_ delta: Double) {
        let next = max(0, target + delta)
        weightInput = next.clean
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Colori indicativi dei dischi da palestra.
    private func plateColor(_ plate: Double) -> Color {
        switch plate {
        case 25: return .ringRed
        case 20: return .gymBlue
        case 15: return .gymOrange
        case 10: return .gymGreen
        case 5:  return Color(hex: "AEAEB2")
        default: return Color(hex: "6E6E73")
        }
    }

    private func plateHeight(_ plate: Double) -> CGFloat {
        // Scala compressa: anche 1.25 kg resta visibile
        30 + CGFloat(plate / 25.0) * 60
    }
}
