import SwiftData
import Foundation

// MARK: - Food Item

@Model
final class FoodItem {
    var name: String
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double
    var sugarPer100g: Double
    var saturatedFatPer100g: Double
    var portionName: String?
    var portionGrams: Double?

    init(name: String, kcalPer100g: Double, proteinPer100g: Double, carbsPer100g: Double,
         fatPer100g: Double, fiberPer100g: Double = 0, sugarPer100g: Double = 0,
         saturatedFatPer100g: Double = 0, portionName: String? = nil, portionGrams: Double? = nil) {
        self.name = name; self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g; self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g; self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g; self.saturatedFatPer100g = saturatedFatPer100g
        self.portionName = portionName; self.portionGrams = portionGrams
    }

    func kcal(for g: Double) -> Double { kcalPer100g * g / 100 }
    func protein(for g: Double) -> Double { proteinPer100g * g / 100 }
    func carbs(for g: Double) -> Double { carbsPer100g * g / 100 }
    func fat(for g: Double) -> Double { fatPer100g * g / 100 }
    func fiber(for g: Double) -> Double { fiberPer100g * g / 100 }
    func sugar(for g: Double) -> Double { sugarPer100g * g / 100 }
    func saturatedFat(for g: Double) -> Double { saturatedFatPer100g * g / 100 }
}

// MARK: - Food Entry

@Model
final class FoodEntry {
    var date: Date
    var dayKey: String
    var meal: MealType
    var grams: Double
    var foodName: String
    var kcalSnapshot: Double
    var proteinSnapshot: Double
    var carbsSnapshot: Double
    var fatSnapshot: Double
    var fiberSnapshot: Double
    var sugarSnapshot: Double
    var saturatedFatSnapshot: Double

    init(food: FoodItem, grams: Double, meal: MealType, date: Date) {
        self.date = date; self.dayKey = date.dateKey; self.meal = meal; self.grams = grams
        self.foodName = food.name
        self.kcalSnapshot = food.kcal(for: grams); self.proteinSnapshot = food.protein(for: grams)
        self.carbsSnapshot = food.carbs(for: grams); self.fatSnapshot = food.fat(for: grams)
        self.fiberSnapshot = food.fiber(for: grams); self.sugarSnapshot = food.sugar(for: grams)
        self.saturatedFatSnapshot = food.saturatedFat(for: grams)
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Colazione"; case lunch = "Pranzo"
    case dinner = "Cena"; case snack = "Snack"
}

// MARK: - Day Log

@Model
final class DayLog {
    @Attribute(.unique) var dateKey: String
    var weight: Double?
    var steps: Int
    var gymColor: GymColor

    init(dateKey: String) {
        self.dateKey = dateKey; self.weight = nil; self.steps = 0; self.gymColor = .rest
    }

    var burnedKcal: Int {
        Int(Double(steps) * 0.04) + (gymColor == .rest ? 0 : 300)
    }
}

enum GymColor: String, Codable, CaseIterable {
    case rest = "rest"; case orange = "orange"; case blue = "blue"
    case green = "green"; case pink = "pink"
}

// MARK: - App Limits

@Model
final class AppLimits {
    var kcalTarget: Double
    var proteinTarget: Double
    var carbsTarget: Double
    var fatTarget: Double
    var fiberTarget: Double
    var sugarTarget: Double
    var saturatedFatTarget: Double
    var stepsTarget: Int
    var weightTarget: Double
    var startDate: Date      // data inizio tracciamento risultati

    init() {
        self.kcalTarget = 2255; self.proteinTarget = 200; self.carbsTarget = 300
        self.fatTarget = 70; self.fiberTarget = 30; self.sugarTarget = 50
        self.saturatedFatTarget = 20; self.stepsTarget = 10000; self.weightTarget = 85
        self.startDate = Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Date Helpers

extension Date {
    var dateKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: self)
    }
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    var isFuture: Bool { self > Calendar.current.startOfDay(for: Date()).adding(days: 1) }
    var displayLabel: String {
        if isToday { return "Oggi" }
        if isYesterday { return "Ieri" }
        let diff = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: self)).day ?? 0
        if diff == 1 { return "Domani" }
        return ""
    }
    var fullDisplay: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMM"; return f.string(from: self).capitalized
    }
}
