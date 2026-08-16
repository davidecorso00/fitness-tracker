import CoreGraphics
import Foundation

// "Segui la forma col dito".
//
// Compito visuospaziale: secondo la teoria dell'Elaborated Intrusion il
// desiderio di cibo si regge su un'immagine mentale, e occupare il canale
// visuospaziale la indebolisce più di un compito verbale. È il motivo per cui
// questa attività viene prima dei calcoli e delle curiosità.
//
// Deliberatamente senza punteggio, senza tempo e senza errori: se il dito esce
// dalla traccia non succede niente, semplicemente non si avanza. Un compito
// valutabile aggiungerebbe stress a un momento che ne ha già.

struct TraceShape: Equatable {

    /// Punti in spazio unitario (0…1 su entrambi gli assi).
    let points: [CGPoint]
    let name: String

    /// Quanto può allontanarsi il dito dal punto atteso, in unità di spazio
    /// unitario. Generosa di proposito.
    static let tolerance: CGFloat = 0.13

    // MARK: - Forme

    /// Curve parametriche lisce, tutte chiuse e senza spigoli.
    /// L'indice sceglie la forma in modo deterministico, così i test sono stabili.
    static func shape(index: Int, samples: Int = 220) -> TraceShape {
        let kind = index %% 4
        let name: String
        let f: (Double) -> CGPoint

        switch kind {
        case 0:
            name = "spirale"
            f = { t in
                let turns = 2.6
                let a = t * turns * 2 * .pi
                let r = 0.08 + 0.36 * t
                return CGPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a))
            }
        case 1:
            name = "otto"
            f = { t in
                let a = t * 2 * .pi
                return CGPoint(x: 0.5 + 0.34 * sin(a),
                               y: 0.5 + 0.30 * sin(a) * cos(a) * 2)
            }
        case 2:
            name = "petalo"
            f = { t in
                let a = t * 2 * .pi
                let r = 0.34 * cos(3 * a).magnitude.squareRoot()
                return CGPoint(x: 0.5 + r * cos(a), y: 0.5 + r * sin(a))
            }
        default:
            name = "onda"
            f = { t in
                let a = t * 2 * .pi
                return CGPoint(x: 0.5 + 0.36 * cos(a),
                               y: 0.5 + 0.22 * sin(2 * a))
            }
        }

        let pts = (0...samples).map { f(Double($0) / Double(samples)) }
        return TraceShape(points: pts, name: name)
    }

    // MARK: - Avanzamento

    /// Nuovo indice raggiunto dato il dito in `finger` e l'indice attuale.
    ///
    /// Avanza solo in ordine e solo se il dito è abbastanza vicino: si può
    /// tornare indietro sulla traccia senza perdere il progresso, e saltare
    /// avanti non funziona.
    func advance(from current: Int, finger: CGPoint) -> Int {
        guard !points.isEmpty else { return current }
        var i = min(max(current, 0), points.count - 1)
        // Guarda un po' avanti: il dito si muove più veloce del campionamento.
        let lookahead = 12
        let limit = min(i + lookahead, points.count - 1)
        while i < limit {
            let next = points[i + 1]
            let dx = finger.x - next.x
            let dy = finger.y - next.y
            guard (dx * dx + dy * dy).squareRoot() <= Self.tolerance else { break }
            i += 1
        }
        return i
    }

    var isComplete: Bool { false }   // completata quando l'indice arriva in fondo

    func isComplete(_ index: Int) -> Bool {
        index >= points.count - 1
    }

    /// Quota percorsa, 0…1. Serve solo a disegnare: non viene mai mostrata
    /// come numero o percentuale.
    func progress(_ index: Int) -> Double {
        guard points.count > 1 else { return 0 }
        return Double(index) / Double(points.count - 1)
    }
}

infix operator %%: MultiplicationPrecedence

/// Modulo sempre positivo, anche con indici negativi.
func %% (a: Int, b: Int) -> Int {
    let r = a % b
    return r < 0 ? r + b : r
}
