import Foundation

// Logica del focus calorie e dell'inserimento rapido, senza dipendenze da
// SwiftData: è la parte che decide quantità e budget, quindi deve poter essere
// verificata a parte. L'aggancio ai modelli sta in FoodQuickLog.swift.

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
