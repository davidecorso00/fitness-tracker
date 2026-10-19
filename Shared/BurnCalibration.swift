import Foundation

// Calibrazione del consumo sulla bilancia.
//
// Idea: se si conosce quanto si è mangiato e di quanto è cambiato il peso, il
// consumo reale è la differenza. In kg/giorno la pendenza del peso vale
// (mangiato − consumato) / 7700, quindi
//
//     consumo osservato = media kcal mangiate − 7700 × pendenza
//
// Usa la stessa equivalenza (7700 kcal/kg) del resto dell'app, così i kg previsti
// dal deficit e quelli della bilancia si confrontano con lo stesso metro.
//
// Cosa NON sa fare: distinguere un consumo diverso dalla stima da cibo non
// registrato (olio, assaggi, bevande) o da un'oscillazione d'acqua. Vale come
// "mantenimento nelle calorie che registri", con il suo margine d'errore.

/// Un giorno concluso con il cibo registrato. `index` = giorni dall'inizio della finestra.
struct CalibrationDay: Equatable {
    var index: Int
    var eaten: Double
    /// Consumo stimato dall'app per lo stesso giorno (basale + digestione + movimento).
    var estimatedBurn: Double
}

/// Una pesata. `index` come sopra.
struct CalibrationWeight: Equatable {
    var index: Int
    var kg: Double
}

struct BurnCalibration: Equatable {
    var observedKcal: Double
    var estimatedKcal: Double
    /// Metà dell'intervallo di confidenza al 95%, in kcal/giorno.
    var marginKcal: Double
    var slopeKgPerWeek: Double
    var loggedDays: Int
    var weighIns: Int

    /// Quanto il consumo osservato si discosta dalla stima (1 = coincidono).
    var ratio: Double { estimatedKcal > 0 ? observedKcal / estimatedKcal : 1 }
}

enum BurnCalibrationResult: Equatable {
    case notEnoughData(loggedDays: Int, weighIns: Int, spanDays: Int)
    case ready(BurnCalibration)
}

enum BurnCalibrationRules {
    static let kcalPerKg = 7700.0
    /// Finestra di giorni conclusi considerata.
    static let windowDays = 28
    static let minLoggedDays = 14
    static let minWeighIns = 8
    /// Distanza minima fra la prima e l'ultima pesata: meno di così la pendenza
    /// è dominata dall'acqua.
    static let minSpanDays = 14
}

func burnCalibration(days: [CalibrationDay], weights: [CalibrationWeight]) -> BurnCalibrationResult {
    let logged = days.filter { $0.eaten > 0 && $0.estimatedBurn > 0 }
    let ws = weights.filter { $0.kg > 0 }.sorted { $0.index < $1.index }
    let span = (ws.last?.index ?? 0) - (ws.first?.index ?? 0)

    guard logged.count >= BurnCalibrationRules.minLoggedDays,
          ws.count >= BurnCalibrationRules.minWeighIns,
          span >= BurnCalibrationRules.minSpanDays else {
        return .notEnoughData(loggedDays: logged.count, weighIns: ws.count, spanDays: span)
    }

    // Retta dei minimi quadrati sulle pesate, senza riempire i giorni mancanti.
    let n = Double(ws.count)
    let meanX = ws.reduce(0) { $0 + Double($1.index) } / n
    let meanY = ws.reduce(0) { $0 + $1.kg } / n
    let sxx = ws.reduce(0) { $0 + pow(Double($1.index) - meanX, 2) }
    guard sxx > 0 else {
        return .notEnoughData(loggedDays: logged.count, weighIns: ws.count, spanDays: span)
    }
    let sxy = ws.reduce(0) { $0 + (Double($1.index) - meanX) * ($1.kg - meanY) }
    let slope = sxy / sxx                       // kg al giorno
    let intercept = meanY - slope * meanX
    let sse = ws.reduce(0) { acc, w in
        let fit = intercept + slope * Double(w.index)
        return acc + pow(w.kg - fit, 2)
    }
    let slopeError = (sse / (n - 2) / sxx).squareRoot()

    let avgEaten = logged.reduce(0) { $0 + $1.eaten } / Double(logged.count)
    let avgEstimated = logged.reduce(0) { $0 + $1.estimatedBurn } / Double(logged.count)
    let observed = avgEaten - BurnCalibrationRules.kcalPerKg * slope
    let margin = 1.96 * BurnCalibrationRules.kcalPerKg * slopeError

    return .ready(BurnCalibration(observedKcal: observed, estimatedKcal: avgEstimated,
                                  marginKcal: margin, slopeKgPerWeek: slope * 7,
                                  loggedDays: logged.count, weighIns: ws.count))
}
