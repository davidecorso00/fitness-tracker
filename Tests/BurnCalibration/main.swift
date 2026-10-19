import Foundation

// Verifica della calibrazione del consumo sulla bilancia.

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}

func days(_ n: Int, eaten: Double, burn: Double) -> [CalibrationDay] {
    (0..<n).map { CalibrationDay(index: $0, eaten: eaten, estimatedBurn: burn) }
}

print("\n1. Dati sufficienti: il consumo si ricava da cibo e peso")

// Mangia 2000 kcal al giorno e consuma 2300: 300 kcal / 7700 = 0,039 kg al giorno in meno.
let slopePerDay = -300.0 / 7700.0
let weights = stride(from: 0, to: 28, by: 2).map {
    CalibrationWeight(index: $0, kg: 80 + slopePerDay * Double($0))
}
if case let .ready(c) = burnCalibration(days: days(28, eaten: 2000, burn: 2600), weights: weights) {
    check("consumo osservato = 2300", abs(c.observedKcal - 2300) < 1)
    check("stima dell'app = 2600", abs(c.estimatedKcal - 2600) < 1)
    check("pendenza = -0,27 kg a settimana", abs(c.slopeKgPerWeek - (-300.0 / 7700.0 * 7)) < 1e-6)
    check("rapporto sotto 1", c.ratio < 1)
    check("senza rumore il margine è nullo", c.marginKcal < 1)
    check("giorni e pesate contati", c.loggedDays == 28 && c.weighIns == 14)
} else {
    check("dati sufficienti → risultato", false)
}

print("\n2. Peso stabile: consumo = mangiato")

let flat = stride(from: 0, to: 28, by: 2).map { CalibrationWeight(index: $0, kg: 80) }
if case let .ready(c) = burnCalibration(days: days(28, eaten: 2400, burn: 2400), weights: flat) {
    check("consumo osservato = 2400", abs(c.observedKcal - 2400) < 1)
    check("in linea con la stima", abs(c.ratio - 1) < 0.001)
} else {
    check("peso stabile → risultato", false)
}

print("\n3. Dati insufficienti")

check("poche pesate",
      burnCalibration(days: days(28, eaten: 2000, burn: 2600), weights: Array(weights.prefix(5)))
        == .notEnoughData(loggedDays: 28, weighIns: 5, spanDays: 8))
check("pochi giorni registrati",
      { if case .notEnoughData = burnCalibration(days: days(10, eaten: 2000, burn: 2600), weights: weights) { return true }; return false }())
check("giorni a 0 kcal non contano",
      { if case .notEnoughData(let d, _, _) = burnCalibration(days: days(28, eaten: 0, burn: 2600), weights: weights) { return d == 0 }; return false }())
check("pesate troppo vicine nel tempo",
      { if case .notEnoughData = burnCalibration(days: days(28, eaten: 2000, burn: 2600),
                                                 weights: (0..<10).map { CalibrationWeight(index: $0, kg: 80) }) { return true }; return false }())

print("")
if failures == 0 { print("Tutti i controlli superati"); exit(0) }
else { print("\(failures) controlli falliti"); exit(1) }
