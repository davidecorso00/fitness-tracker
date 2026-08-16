import Foundation
import SwiftData

// Aggancio fra i modelli SwiftData e la logica pura in CalorieLogic.swift.
//
// La maggior parte dei pasti è una ripetizione: gli stessi alimenti, nelle stesse
// quantità, allo stesso pasto. Qui si ricava dallo storico quello che serve per
// ri-registrarli con un tap, riusando i valori esatti già salvati invece di
// ricalcolarli — così una porzione pesata resta quella.

extension FoodEntry {
    var snapshot: FoodEntrySnapshot {
        FoodEntrySnapshot(
            foodName: foodName, grams: grams,
            kcal: kcalSnapshot, protein: proteinSnapshot, carbs: carbsSnapshot,
            fat: fatSnapshot, fiber: fiberSnapshot, sugar: sugarSnapshot,
            saturatedFat: saturatedFatSnapshot, salt: saltSnapshot,
            date: date, meal: meal)
    }
}

extension Sequence<FoodEntry> {

    /// Alimenti recenti pronti da ri-registrare, filtrati per pasto.
    func recentFoods(meal: MealType? = nil, limit: Int = 20) -> [RecentFood] {
        makeRecentFoods(from: map(\.snapshot), meal: meal, limit: limit)
    }

    /// Le voci di un pasto in un certo giorno.
    func entries(on dayKey: String, meal: MealType) -> [FoodEntry] {
        filter { $0.dayKey == dayKey && $0.meal == meal }
    }
}

// MARK: - Registrazione

@MainActor
enum QuickLog {

    /// Ri-registra un alimento recente con la stessa quantità di prima.
    @discardableResult
    static func add(_ recent: RecentFood, meal: MealType, date: Date,
                    context: ModelContext) -> FoodEntry {
        let entry = FoodEntry(
            foodName: recent.foodName, grams: recent.grams, meal: meal, date: date,
            kcal: recent.kcal, protein: recent.protein, carbs: recent.carbs,
            fat: recent.fat, fiber: recent.fiber, sugar: recent.sugar,
            saturatedFat: recent.saturatedFat, salt: recent.salt)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Copia tutte le voci di un pasto in un altro giorno. Restituisce quante ne
    /// ha copiate, 0 se nel giorno di origine quel pasto era vuoto.
    @discardableResult
    static func copyMeal(_ sourceEntries: [FoodEntry], to date: Date, meal: MealType,
                         context: ModelContext) -> Int {
        guard !sourceEntries.isEmpty else { return 0 }
        for source in sourceEntries {
            let copy = FoodEntry(
                foodName: source.foodName, grams: source.grams, meal: meal, date: date,
                kcal: source.kcalSnapshot, protein: source.proteinSnapshot,
                carbs: source.carbsSnapshot, fat: source.fatSnapshot,
                fiber: source.fiberSnapshot, sugar: source.sugarSnapshot,
                saturatedFat: source.saturatedFatSnapshot, salt: source.saltSnapshot)
            context.insert(copy)
        }
        try? context.save()
        return sourceEntries.count
    }
}
