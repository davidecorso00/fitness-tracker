import Foundation

// Logica del focus calorie e dell'inserimento rapido, senza dipendenze da
// SwiftData: è la parte che decide quantità e budget, quindi deve poter essere
// verificata a parte. L'aggancio ai modelli sta in FoodQuickLog.swift.

// MARK: - Pasti

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Colazione"; case lunch = "Pranzo"
    case dinner = "Cena"; case snack = "Snack"

    /// Quota predefinita del target giornaliero. Serve a sapere quante calorie
    /// restano *per questo pasto*, non solo per la giornata: è la cena a sforare,
    /// e con il solo totale giornaliero te ne accorgi a cena finita.
    var defaultBudgetShare: Double {
        switch self {
        case .breakfast: return 0.25
        case .lunch:     return 0.35
        case .dinner:    return 0.30
        case .snack:     return 0.10
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.fill"
        case .snack:     return "carrot.fill"
        }
    }
}

// MARK: - Formattazione

extension Double {
    /// "20" invece di "20.0", ma "22.5" resta "22.5".
    var clean: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}

// MARK: - Voce di diario, in sola lettura

/// Copia leggera di una voce già registrata. Serve a ragionare sullo storico
/// senza passarsi dietro oggetti gestiti dal database.
struct FoodEntrySnapshot {
    var foodName: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var saturatedFat: Double
    var salt: Double
    var date: Date
    var meal: MealType
}

// MARK: - Alimento recente

struct RecentFood: Identifiable, Hashable {
    var id: String { foodName }

    var foodName: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var saturatedFat: Double
    var salt: Double
    var lastUsed: Date
    var timesUsed: Int

    init(from s: FoodEntrySnapshot) {
        foodName = s.foodName
        grams = s.grams
        kcal = s.kcal
        protein = s.protein
        carbs = s.carbs
        fat = s.fat
        fiber = s.fiber
        sugar = s.sugar
        saturatedFat = s.saturatedFat
        salt = s.salt
        lastUsed = s.date
        timesUsed = 1
    }
}

/// Alimenti registrati di recente, uno per nome, con la quantità dell'ultima volta.
///
/// La porzione riportata è quella dell'uso **più recente**, non della prima
/// occorrenza incontrata: se ieri hai pesato 200 g di pollo e la settimana scorsa
/// 150 g, la scorciatoia deve proporre 200 g.
///
/// Se `meal` è indicato considera solo quel pasto: a colazione ha senso vedere
/// la colazione, non la cena di ieri.
func makeRecentFoods(from history: [FoodEntrySnapshot],
                     meal: MealType? = nil,
                     limit: Int = 20) -> [RecentFood] {
    var byName: [String: RecentFood] = [:]
    for entry in history {
        if let meal, entry.meal != meal { continue }
        guard var existing = byName[entry.foodName] else {
            byName[entry.foodName] = RecentFood(from: entry)
            continue
        }
        let times = existing.timesUsed + 1
        if entry.date > existing.lastUsed {
            existing = RecentFood(from: entry)   // porzione più recente
        }
        existing.timesUsed = times
        byName[entry.foodName] = existing
    }
    return byName.values
        .sorted { $0.lastUsed > $1.lastUsed }
        .prefix(limit)
        .map { $0 }
}

// MARK: - Ritmo dei pasti

// La regolarità dei pasti è l'intervento numero uno della CBT-E contro le
// abbuffate: tre pasti più due o tre spuntini, senza restare troppe ore da
// sveglio senza mangiare. È l'opposto di una serie di giorni in deficit —
// premia il mangiare abbastanza, non il mangiare poco.

struct MealRhythm: Equatable {
    /// Occasioni distinte in cui si è mangiato. Voci registrate a pochi minuti
    /// l'una dall'altra contano come una sola: un pranzo sono tre alimenti,
    /// non tre pasti.
    var occasions: Int
    /// Intervallo più lungo fra due occasioni, in ore.
    var longestGapHours: Double
    var isRegular: Bool

    static let empty = MealRhythm(occasions: 0, longestGapHours: 0, isRegular: false)
}

/// Occasioni minime e intervallo massimo perché una giornata sia regolare.
/// La soglia è volutamente più larga delle 4 ore del protocollo: un criterio
/// troppo stretto trasformerebbe l'indicatore nell'ennesima cosa da fallire.
let regularMealsMinOccasions = 3
let regularMealsMaxGapHours: Double = 5

/// Voci ravvicinate entro questo intervallo appartengono allo stesso pasto.
private let sameOccasionMinutes: Double = 45

/// Ritmo di una singola giornata. `entries` deve contenere solo quel giorno.
func mealRhythm(for entries: [FoodEntrySnapshot]) -> MealRhythm {
    let times = entries.map(\.date).sorted()
    guard !times.isEmpty else { return .empty }

    // Raggruppa in occasioni
    var occasionStarts: [Date] = [times[0]]
    for t in times.dropFirst() {
        if let last = occasionStarts.last,
           t.timeIntervalSince(last) > sameOccasionMinutes * 60 {
            occasionStarts.append(t)
        }
    }

    // Intervallo più lungo fra un'occasione e la successiva
    var longest: Double = 0
    for (a, b) in zip(occasionStarts, occasionStarts.dropFirst()) {
        longest = max(longest, b.timeIntervalSince(a) / 3600)
    }

    let regolare = occasionStarts.count >= regularMealsMinOccasions
        && longest <= regularMealsMaxGapHours

    return MealRhythm(occasions: occasionStarts.count,
                      longestGapHours: longest,
                      isRegular: regolare)
}

/// Quante giornate regolari negli ultimi `days` giorni conclusi.
///
/// È una finestra mobile, non una catena: saltare un giorno fa scendere il
/// conteggio di uno, non azzerarlo. Una catena che si spezza pesa proprio nei
/// giorni in cui pesa già tutto il resto, ed è il meccanismo che rende difficile
/// ricominciare.
struct MealRegularity: Equatable {
    var regularDays: Int
    var window: Int
    /// Ore dall'ultima volta che si è mangiato. nil se non c'è nessuna voce.
    var hoursSinceLastMeal: Double?
    /// Esito giorno per giorno, dal più vecchio al più recente.
    var recent: [Bool]

    var allRegular: Bool { regularDays == window && window > 0 }
}

func mealRegularity(entriesByDay: [String: [FoodEntrySnapshot]],
                    days: [String],
                    now: Date,
                    lastMealDate: Date?) -> MealRegularity {
    let esiti = days.map { mealRhythm(for: entriesByDay[$0] ?? []).isRegular }
    return MealRegularity(
        regularDays: esiti.filter { $0 }.count,
        window: days.count,
        hoursSinceLastMeal: lastMealDate.map { now.timeIntervalSince($0) / 3600 },
        recent: esiti)
}

// MARK: - Budget calorico

/// Come sta andando la giornata (o il singolo pasto) rispetto al target.
/// Serve a mostrare le calorie che restano *prima* di confermare una porzione.
struct CalorieBudget {
    var consumed: Double
    var target: Double

    var remaining: Double { target - consumed }
    var isOver: Bool { consumed > target }
    /// Quota consumata. Non limitata a 1, così l'eccesso resta rappresentabile.
    var progress: Double { target > 0 ? consumed / target : 0 }

    /// Come cambierebbe aggiungendo `kcal`.
    func adding(_ kcal: Double) -> CalorieBudget {
        CalorieBudget(consumed: consumed + kcal, target: target)
    }

    /// Testo neutro sullo stato: informa, non giudica.
    var shortLabel: String {
        if target <= 0 { return "—" }
        return isOver
            ? "+\(Int(consumed - target)) kcal sul target"
            : "\(Int(remaining)) kcal rimaste"
    }
}

/// Ripartisce il target giornaliero fra i pasti.
/// Con quote tutte a zero usa la ripartizione predefinita; altrimenti normalizza
/// quelle indicate, così non serve che sommino esattamente a 100.
func mealBudget(dailyTarget: Double, meal: MealType, shares: [MealType: Double]) -> Double {
    let total = shares.values.reduce(0, +)
    guard total > 0 else { return dailyTarget * meal.defaultBudgetShare }
    return dailyTarget * ((shares[meal] ?? 0) / total)
}
