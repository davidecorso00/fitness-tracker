import Foundation

// Logica della palestra, senza dipendenze da SwiftData: caricamento del
// bilanciere e proposta del carico successivo. Sta a parte per poter essere
// verificata dai test in Scripts/test.sh.

// MARK: - Caricamento bilanciere

/// Dischi disponibili in palestra, per lato, in kg. Dal più pesante al più leggero.
let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 2, 1.25]

/// Pesi tipici dei bilancieri.
enum BarWeight: Double, CaseIterable, Identifiable {
    case olympic20 = 20
    case olympic15 = 15
    case ez10      = 10
    case none      = 0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .olympic20: return "Olimpico 20 kg"
        case .olympic15: return "Olimpico 15 kg"
        case .ez10:      return "EZ / corto 10 kg"
        case .none:      return "Senza bilanciere"
        }
    }
}

struct PlateLoad: Equatable {
    /// Dischi da mettere **per lato**, dal più pesante al più leggero.
    var perSide: [Double]
    /// Peso effettivamente raggiunto (bilanciere + dischi su entrambi i lati).
    var achieved: Double
    /// Differenza rispetto al peso richiesto. 0 = esatto.
    var difference: Double

    var isExact: Bool { abs(difference) < 0.001 }
    var isImpossible: Bool { perSide.isEmpty && difference != 0 }
}

/// Quali dischi caricare per lato per arrivare a `target`.
///
/// Approccio greedy dal disco più pesante: con la dotazione standard di una
/// palestra è ottimo, e quando il peso esatto non è raggiungibile (per esempio
/// 47 kg senza dischi da 0.5) resta sotto e riporta quanto manca, invece di
/// arrotondare in silenzio.
func plateLoad(target: Double, bar: Double, plates: [Double] = standardPlates) -> PlateLoad {
    guard target >= bar else {
        return PlateLoad(perSide: [], achieved: bar, difference: target - bar)
    }
    var remainingPerSide = (target - bar) / 2
    var used: [Double] = []
    for plate in plates.sorted(by: >) {
        while remainingPerSide >= plate - 0.0001 {
            used.append(plate)
            remainingPerSide -= plate
        }
    }
    let achieved = bar + used.reduce(0, +) * 2
    return PlateLoad(perSide: used, achieved: achieved, difference: target - achieved)
}

/// Riepilogo compatto: "2×20 + 1×5" per lato.
func plateSummary(_ perSide: [Double]) -> String {
    guard !perSide.isEmpty else { return "solo bilanciere" }
    var counts: [(plate: Double, n: Int)] = []
    for p in perSide {
        if let last = counts.last, last.plate == p { counts[counts.count - 1].n += 1 }
        else { counts.append((p, 1)) }
    }
    return counts
        .map { "\($0.n)×\($0.plate == $0.plate.rounded() ? String(Int($0.plate)) : String($0.plate))" }
        .joined(separator: " + ")
}

// MARK: - Progressione del carico

/// Una serie già registrata, ridotta ai valori che servono alla progressione.
struct SetRecord {
    var reps: Int
    var weight: Double
    var completed: Bool
}

/// Sessione passata per un esercizio.
struct ExerciseSessionRecord {
    var date: Date
    var sets: [SetRecord]

    var completedSets: [SetRecord] { sets.filter(\.completed) }
    var topWeight: Double { completedSets.map(\.weight).max() ?? 0 }
    var totalReps: Int { completedSets.reduce(0) { $0 + $1.reps } }
    var volume: Double { completedSets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
}

enum ProgressionAdvice: Equatable {
    /// Hai chiuso tutte le serie in cima alla forbice: sali di peso.
    case increaseWeight(to: Double, from: Double)
    /// Sei dentro la forbice ma non in cima: aggiungi ripetizioni.
    case addReps(target: Int, current: Int)
    /// Sotto la forbice: consolida allo stesso carico.
    case hold(weight: Double)
    /// Due sessioni di fila in calo: valuta di scaricare.
    case deload(to: Double)
    /// Storico insufficiente.
    case notEnoughData
}

/// Incremento minimo praticabile: 2.5 kg per lato non esiste sotto i 20 kg
/// di bilanciere scarico, quindi si scala sui carichi bassi.
func weightStep(for weight: Double, isBarbell: Bool) -> Double {
    if !isBarbell { return weight < 20 ? 1 : 2 }   // manubri e macchine
    return weight < 40 ? 2.5 : 5                    // bilanciere: 1.25 o 2.5 per lato
}

/// Proposta per la prossima seduta di un esercizio.
///
/// Regola a doppia progressione, quella che usano quasi tutti i programmi di
/// forza: si resta allo stesso carico finché non si chiudono tutte le serie in
/// cima alla forbice di ripetizioni, poi si sale di peso e si riparte dal fondo.
func progressionAdvice(history: [ExerciseSessionRecord],
                       repRange: ClosedRange<Int> = 8...12,
                       isBarbell: Bool = true) -> ProgressionAdvice {
    let sessions = history.sorted { $0.date > $1.date }
    guard let last = sessions.first, !last.completedSets.isEmpty else {
        return .notEnoughData
    }

    // Due cali consecutivi di volume: meglio scaricare che insistere.
    if sessions.count >= 3 {
        let v = sessions.prefix(3).map(\.volume)
        if v[0] < v[1], v[1] < v[2], v[2] > 0 {
            return .deload(to: (last.topWeight * 0.9 / 2.5).rounded() * 2.5)
        }
    }

    let working = last.completedSets.filter { $0.weight == last.topWeight }
    guard !working.isEmpty else { return .hold(weight: last.topWeight) }

    let minReps = working.map(\.reps).min() ?? 0
    if minReps >= repRange.upperBound {
        let step = weightStep(for: last.topWeight, isBarbell: isBarbell)
        return .increaseWeight(to: last.topWeight + step, from: last.topWeight)
    }
    if minReps >= repRange.lowerBound {
        return .addReps(target: min(minReps + 1, repRange.upperBound), current: minReps)
    }
    return .hold(weight: last.topWeight)
}

extension ProgressionAdvice {
    /// Testo mostrato all'utente. Suggerisce, non prescrive.
    var message: String {
        switch self {
        case .increaseWeight(let to, let from):
            return "Hai chiuso tutte le serie: prova \(to.clean) kg (da \(from.clean))"
        case .addReps(let target, let current):
            return "Stesso carico, punta a \(target) ripetizioni (ultima volta \(current))"
        case .hold(let weight):
            return "Consolida a \(weight.clean) kg"
        case .deload(let to):
            return "Due sedute in calo: valuta una settimana più leggera, ~\(to.clean) kg"
        case .notEnoughData:
            return "Serve almeno una seduta registrata"
        }
    }

    var icon: String {
        switch self {
        case .increaseWeight: return "arrow.up.circle.fill"
        case .addReps:        return "plus.circle.fill"
        case .hold:           return "equal.circle.fill"
        case .deload:         return "arrow.down.circle.fill"
        case .notEnoughData:  return "questionmark.circle"
        }
    }
}

extension Double {
    /// "20" invece di "20.0", ma "22.5" resta "22.5".
    var clean: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}
