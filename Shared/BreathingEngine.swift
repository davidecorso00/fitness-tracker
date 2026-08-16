import Foundation

// Respirazione guidata: 4 secondi dentro, 6 fuori, sei cicli.
//
// L'espirazione più lunga dell'inspirazione non è estetica: è la parte che
// attiva il ramo parasimpatico e abbassa l'attivazione. Il rapporto viene dalla
// web app "Un Attimo" e resta invariato.
//
// Come gli altri timer dell'app, il tempo è ancorato a date reali e non a un
// contatore incrementale: se il telefono sospende l'app o il tick salta, al
// ritorno la fase è comunque quella giusta.

struct BreathPhase: Equatable {
    enum Kind: Equatable { case inhale, exhale }

    let kind: Kind
    let duration: TimeInterval

    var label: String {
        switch kind {
        case .inhale: return "Inspira"
        case .exhale: return "Espira"
        }
    }

    /// Quanto si espande il cerchio in questa fase.
    var scale: Double {
        switch kind {
        case .inhale: return 1.35
        case .exhale: return 0.80
        }
    }
}

struct BreathingPlan: Equatable {
    var cycles: Int = 6
    var inhale: TimeInterval = 4
    var exhale: TimeInterval = 6

    var phases: [BreathPhase] {
        (0..<max(cycles, 1)).flatMap { _ in
            [BreathPhase(kind: .inhale, duration: inhale),
             BreathPhase(kind: .exhale, duration: exhale)]
        }
    }

    var totalDuration: TimeInterval { Double(cycles) * (inhale + exhale) }
}

/// Dove si trova la respirazione a un dato istante.
struct BreathingState: Equatable {
    var phase: BreathPhase?
    var phaseIndex: Int
    /// Cicli completati, per i puntini in fondo allo schermo.
    var completedCycles: Int
    /// Quanto manca alla fine della fase corrente.
    var remainingInPhase: TimeInterval
    var isFinished: Bool

    static let finished = BreathingState(
        phase: nil, phaseIndex: 0, completedCycles: 0,
        remainingInPhase: 0, isFinished: true)
}

extension BreathingPlan {
    /// Stato della respirazione dopo `elapsed` secondi dall'inizio.
    ///
    /// Funzione pura: nessun timer, nessuno stato interno. La vista chiede
    /// "dove siamo adesso" a ogni tick e questa risponde.
    func state(at elapsed: TimeInterval) -> BreathingState {
        guard elapsed >= 0 else {
            return BreathingState(phase: phases.first, phaseIndex: 0,
                                  completedCycles: 0,
                                  remainingInPhase: inhale, isFinished: false)
        }
        guard elapsed < totalDuration else { return .finished }

        let all = phases
        var acc: TimeInterval = 0
        for (i, phase) in all.enumerated() {
            let end = acc + phase.duration
            if elapsed < end {
                return BreathingState(
                    phase: phase,
                    phaseIndex: i,
                    completedCycles: i / 2,
                    remainingInPhase: end - elapsed,
                    isFinished: false)
            }
            acc = end
        }
        return .finished
    }
}
