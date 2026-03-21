import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var currentDate: Date = Calendar.current.startOfDay(for: Date())

    let healthKit = HealthKitManager()

    func goBack()    { currentDate = currentDate.adding(days: -1) }
    func goForward() { currentDate = currentDate.adding(days: 1) }

    var canGoForward: Bool {
        let tomorrow = Calendar.current.startOfDay(for: Date()).adding(days: 1)
        return currentDate < tomorrow
    }

    var currentDateKey: String { currentDate.dateKey }

    func seedFoodsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<FoodItem>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        let defaults: [FoodItem] = [
            // Originali
            FoodItem(name: "Fiocchi d'avena",  kcalPer100g: 389, proteinPer100g: 14, carbsPer100g: 69, fatPer100g: 8,  fiberPer100g: 10, sugarPer100g: 1,  saturatedFatPer100g: 1.5),
            FoodItem(name: "Petto di pollo",   kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0,  fatPer100g: 3,  fiberPer100g: 0,  sugarPer100g: 0,  saturatedFatPer100g: 0.9),
            FoodItem(name: "Pasta secca",      kcalPer100g: 362, proteinPer100g: 13, carbsPer100g: 75, fatPer100g: 1,  fiberPer100g: 3,  sugarPer100g: 3,  saturatedFatPer100g: 0.2),
            FoodItem(name: "Uova intere",      kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1,  fatPer100g: 11, fiberPer100g: 0,  sugarPer100g: 1,  saturatedFatPer100g: 3.3),
            FoodItem(name: "Riso basmati",     kcalPer100g: 362, proteinPer100g: 7,  carbsPer100g: 79, fatPer100g: 1,  fiberPer100g: 1,  sugarPer100g: 0,  saturatedFatPer100g: 0.2),
            FoodItem(name: "Latte p. scremato",kcalPer100g: 49,  proteinPer100g: 3,  carbsPer100g: 5,  fatPer100g: 2,  fiberPer100g: 0,  sugarPer100g: 5,  saturatedFatPer100g: 1.2),
            // Dalla foto
            FoodItem(name: "Grana padano",     kcalPer100g: 398, proteinPer100g: 33, carbsPer100g: 0,  fatPer100g: 29, fiberPer100g: 0,  sugarPer100g: 0,  saturatedFatPer100g: 19, saltPer100g: 1.5),
            FoodItem(name: "Latte parzialmente scremato", kcalPer100g: 41, proteinPer100g: 3, carbsPer100g: 4, fatPer100g: 1, fiberPer100g: 0, sugarPer100g: 4, saturatedFatPer100g: 0.7, saltPer100g: 0.1),
            FoodItem(name: "Mozzarella proteica", kcalPer100g: 131, proteinPer100g: 20, carbsPer100g: 1, fatPer100g: 5, fiberPer100g: 0, sugarPer100g: 1, saturatedFatPer100g: 3.5, saltPer100g: 0.5),
            FoodItem(name: "Ortolina",         kcalPer100g: 132, proteinPer100g: 2,  carbsPer100g: 19, fatPer100g: 4,  fiberPer100g: 2,  sugarPer100g: 3,  saturatedFatPer100g: 0.5, saltPer100g: 1.5),
            FoodItem(name: "Pane bianco",      kcalPer100g: 268, proteinPer100g: 8,  carbsPer100g: 50, fatPer100g: 1,  fiberPer100g: 2,  sugarPer100g: 3,  saturatedFatPer100g: 0.2, saltPer100g: 2.0),
            FoodItem(name: "Patate lesse sottovuoto", kcalPer100g: 65, proteinPer100g: 2, carbsPer100g: 13, fatPer100g: 0, fiberPer100g: 1, sugarPer100g: 1, saturatedFatPer100g: 0, saltPer100g: 0.1),
            FoodItem(name: "Ringo",            kcalPer100g: 501, proteinPer100g: 5,  carbsPer100g: 65, fatPer100g: 22, fiberPer100g: 3,  sugarPer100g: 30, saturatedFatPer100g: 11, saltPer100g: 0.8, portionName: "pacchetti", portionGrams: 55),
            FoodItem(name: "Salsa pomodoro",   kcalPer100g: 67,  proteinPer100g: 1,  carbsPer100g: 5,  fatPer100g: 3,  fiberPer100g: 0,  sugarPer100g: 4,  saturatedFatPer100g: 0.4, saltPer100g: 0.7),
            FoodItem(name: "Stracchino proteico", kcalPer100g: 169, proteinPer100g: 17, carbsPer100g: 2, fatPer100g: 10, fiberPer100g: 0, sugarPer100g: 2, saturatedFatPer100g: 7, saltPer100g: 0.8),
            FoodItem(name: "Tortiglioni integrali", kcalPer100g: 347, proteinPer100g: 12, carbsPer100g: 63, fatPer100g: 3, fiberPer100g: 8, sugarPer100g: 3, saturatedFatPer100g: 0.5, saltPer100g: 0.1),
            FoodItem(name: "Waffle proteici",  kcalPer100g: 375, proteinPer100g: 25, carbsPer100g: 35, fatPer100g: 15, fiberPer100g: 3,  sugarPer100g: 8,  saturatedFatPer100g: 5,   saltPer100g: 0.8),
        ]
        defaults.forEach { context.insert($0) }

        let limitsDescriptor = FetchDescriptor<AppLimits>()
        if (try? context.fetchCount(limitsDescriptor)) == 0 {
            context.insert(AppLimits())
        }
        try? context.save()
    }

    func dayLog(for dateKey: String, context: ModelContext) -> DayLog {
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = DayLog(dateKey: dateKey)
        context.insert(new)
        return new
    }

    func limits(context: ModelContext) -> AppLimits {
        let descriptor = FetchDescriptor<AppLimits>()
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = AppLimits()
        context.insert(new)
        return new
    }

    struct DayTotals {
        var kcal: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugar: Double = 0
        var saturatedFat: Double = 0
        var salt: Double = 0
    }

    func sportKcal(for dateKey: String, context: ModelContext) -> Double {
        let descriptor = FetchDescriptor<SportEntry>(
            predicate: #Predicate { $0.dayKey == dateKey }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0.0) { $0 + $1.kcalBurned }
    }

    func totalBurned(for dateKey: String, context: ModelContext) -> Double {
        let log = dayLog(for: dateKey, context: context)
        return Double(log.burnedKcal) + sportKcal(for: dateKey, context: context)
    }

    func sportEntries(for dateKey: String, context: ModelContext) -> [SportEntry] {
        let descriptor = FetchDescriptor<SportEntry>(
            predicate: #Predicate { $0.dayKey == dateKey }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func totals(for dateKey: String, context: ModelContext) -> DayTotals {
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { $0.dayKey == dateKey }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(into: DayTotals()) { t, e in
            t.kcal         += e.kcalSnapshot
            t.protein      += e.proteinSnapshot
            t.carbs        += e.carbsSnapshot
            t.fat          += e.fatSnapshot
            t.fiber        += e.fiberSnapshot
            t.sugar        += e.sugarSnapshot
            t.saturatedFat += e.saturatedFatSnapshot
            t.salt         += e.saltSnapshot
        }
    }
}
