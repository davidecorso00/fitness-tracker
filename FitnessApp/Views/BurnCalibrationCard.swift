import SwiftUI

/// Consumo reale ricavato da cibo registrato e peso (Shared/BurnCalibration.swift),
/// confrontato con la stima dell'app. È solo un confronto: non cambia nessun numero.
struct BurnCalibrationCard: View {
    let result: BurnCalibrationResult

    var body: some View {
        switch result {
        case .notEnoughData(let days, let weighIns, let span):
            note("Servono almeno \(BurnCalibrationRules.minLoggedDays) giorni con il cibo registrato, "
                 + "\(BurnCalibrationRules.minWeighIns) pesate e \(BurnCalibrationRules.minSpanDays) giorni "
                 + "fra la prima e l'ultima, negli ultimi \(BurnCalibrationRules.windowDays) giorni. "
                 + "Ora: \(days) giorni, \(weighIns) pesate, \(span) giorni di distanza.")
        case .ready(let c):
            let margin = max(50, (c.marginKcal / 50).rounded(.up) * 50)
            let diff = c.observedKcal - c.estimatedKcal
            let inLine = abs(diff) <= margin
            ResultCard(label: "Consumo osservato (± \(Int(margin)))",
                       value: "\(rounded10(c.observedKcal)) kcal/g",
                       color: .gymBlue, icon: "scalemass.fill")
            ResultCard(label: inLine ? "Stima dell'app: in linea"
                                     : (diff > 0 ? "Stima dell'app: più bassa del reale"
                                                 : "Stima dell'app: più alta del reale"),
                       value: "\(rounded10(c.estimatedKcal)) kcal/g",
                       color: inLine ? .ringGreen : .gymOrange, icon: "flame.fill")
            note("Calcolato su \(c.loggedDays) giorni con il cibo registrato e \(c.weighIns) pesate: "
                 + "media mangiata più il calo del peso (\(String(format: "%+.2f", c.slopeKgPerWeek)) kg a settimana). "
                 + "Se mangi più di quello che registri (olio, assaggi, bevande) il valore esce più basso del reale. "
                 + "Non cambia i numeri dell'app.")
        }
    }

    private func rounded10(_ v: Double) -> Int { Int((v / 10).rounded()) * 10 }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12)).foregroundColor(.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}
