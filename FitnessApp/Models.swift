import SwiftData
import Foundation

// MARK: - Food Item

@Model final class FoodItem {
    var name: String = ""
    var kcalPer100g: Double = 0
    var proteinPer100g: Double = 0
    var carbsPer100g: Double = 0
    var fatPer100g: Double = 0
    var fiberPer100g: Double = 0
    var sugarPer100g: Double = 0
    var saturatedFatPer100g: Double = 0
    var saltPer100g: Double = 0
    var portionName: String? = nil
    var portionGrams: Double? = nil

    init(name: String, kcalPer100g: Double, proteinPer100g: Double, carbsPer100g: Double,
         fatPer100g: Double, fiberPer100g: Double = 0, sugarPer100g: Double = 0,
         saturatedFatPer100g: Double = 0, saltPer100g: Double = 0,
         portionName: String? = nil, portionGrams: Double? = nil) {
        self.name = name; self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g; self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g; self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g; self.saturatedFatPer100g = saturatedFatPer100g
        self.saltPer100g = saltPer100g
        self.portionName = portionName; self.portionGrams = portionGrams
    }

    func kcal(for g: Double) -> Double { kcalPer100g * g / 100 }
    func protein(for g: Double) -> Double { proteinPer100g * g / 100 }
    func carbs(for g: Double) -> Double { carbsPer100g * g / 100 }
    func fat(for g: Double) -> Double { fatPer100g * g / 100 }
    func fiber(for g: Double) -> Double { fiberPer100g * g / 100 }
    func sugar(for g: Double) -> Double { sugarPer100g * g / 100 }
    func saturatedFat(for g: Double) -> Double { saturatedFatPer100g * g / 100 }
    func salt(for g: Double) -> Double { saltPer100g * g / 100 }
}

// MARK: - Food Entry

@Model final class FoodEntry {
    var date: Date = Date()
    var dayKey: String = ""
    var meal: MealType = MealType.breakfast
    var grams: Double = 0
    var foodName: String = ""
    var kcalSnapshot: Double = 0
    var proteinSnapshot: Double = 0
    var carbsSnapshot: Double = 0
    var fatSnapshot: Double = 0
    var fiberSnapshot: Double = 0
    var sugarSnapshot: Double = 0
    var saturatedFatSnapshot: Double = 0
    var saltSnapshot: Double = 0

    init(food: FoodItem, grams: Double, meal: MealType, date: Date) {
        self.date = date; self.dayKey = date.dateKey; self.meal = meal; self.grams = grams
        self.foodName = food.name
        self.kcalSnapshot = food.kcal(for: grams)
        self.proteinSnapshot = food.protein(for: grams)
        self.carbsSnapshot = food.carbs(for: grams)
        self.fatSnapshot = food.fat(for: grams)
        self.fiberSnapshot = food.fiber(for: grams)
        self.sugarSnapshot = food.sugar(for: grams)
        self.saturatedFatSnapshot = food.saturatedFat(for: grams)
        self.saltSnapshot = food.salt(for: grams)
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Colazione"; case lunch = "Pranzo"
    case dinner = "Cena"; case snack = "Snack"
}

// MARK: - Day Log

@Model final class DayLog {
    @Attribute(.unique) var dateKey: String = ""
    var weight: Double? = nil
    var steps: Int = 0
    var gymColor: GymColor = GymColor.rest
    var activeCaloriesBurned: Double = 0
    var basalCaloriesBurned: Double = 0  // mantenuto per compatibilità SwiftData, non più usato

    init(dateKey: String) {
        self.dateKey = dateKey
    }

    /// Calorie bruciate da movimento (HealthKit activeEnergy) o stima da passi.
    /// La quota BMR × 1.2 viene calcolata e aggiunta a livello superiore.
    var burnedKcal: Int {
        let gymBonus = gymColor == .rest ? 0 : 150
        if activeCaloriesBurned > 0 {
            return Int(activeCaloriesBurned) + gymBonus
        }
        if steps > 0 {
            return Int(Double(steps) * 0.04) + gymBonus
        }
        return gymBonus
    }
}

enum GymColor: String, Codable, CaseIterable {
    case rest = "rest"; case orange = "orange"; case blue = "blue"
    case green = "green"; case pink = "pink"
}

// MARK: - Water Entry

@Model final class WaterEntry {
    var dayKey: String = ""
    var liters: Double = 0
    var date: Date = Date()

    init(dayKey: String, liters: Double) {
        self.dayKey = dayKey
        self.liters = liters
        self.date = Date()
    }
}

// MARK: - Sport Entry

@Model final class SportEntry {
    var dayKey: String = ""
    var sportName: String = ""
    var durationMinutes: Int = 30
    var kcalBurned: Double = 0

    init(dayKey: String, sportName: String, durationMinutes: Int, kcalBurned: Double) {
        self.dayKey = dayKey
        self.sportName = sportName
        self.durationMinutes = durationMinutes
        self.kcalBurned = kcalBurned
    }
}

enum SportType: String, CaseIterable, Identifiable {
    case running        = "Corsa"
    case briskWalking   = "Camminata veloce"
    case cycling        = "Ciclismo"
    case swimming       = "Nuoto"
    case soccer         = "Calcio"
    case tennis         = "Tennis"
    case volleyball     = "Pallavolo"
    case basketball     = "Basket"
    case yoga           = "Yoga"
    case boxing         = "Boxe"
    case pilates        = "Pilates"
    case climbing       = "Arrampicata"
    case skiing         = "Sci"
    case skating        = "Pattinaggio"
    case rowing         = "Canottaggio"
    case dancing        = "Danza"
    case martialArts    = "Arti marziali"
    case jumpRope       = "Salto corda"
    case hiking         = "Escursionismo"
    case hiit           = "HIIT"

    var id: String { rawValue }

    var kcalPerHour: Double {
        switch self {
        case .running:       return 600
        case .briskWalking:  return 300
        case .cycling:       return 500
        case .swimming:      return 550
        case .soccer:        return 500
        case .tennis:        return 450
        case .volleyball:    return 350
        case .basketball:    return 500
        case .yoga:          return 200
        case .boxing:        return 700
        case .pilates:       return 250
        case .climbing:      return 600
        case .skiing:        return 500
        case .skating:       return 400
        case .rowing:        return 550
        case .dancing:       return 350
        case .martialArts:   return 600
        case .jumpRope:      return 700
        case .hiking:        return 400
        case .hiit:          return 650
        }
    }

    var icon: String {
        switch self {
        case .running:       return "figure.run"
        case .briskWalking:  return "figure.walk"
        case .cycling:       return "figure.outdoor.cycle"
        case .swimming:      return "figure.pool.swim"
        case .soccer:        return "soccerball"
        case .tennis:        return "tennis.racket"
        case .volleyball:    return "volleyball.fill"
        case .basketball:    return "basketball.fill"
        case .yoga:          return "figure.yoga"
        case .boxing:        return "figure.boxing"
        case .pilates:       return "figure.pilates"
        case .climbing:      return "figure.climbing"
        case .skiing:        return "figure.skiing.downhill"
        case .skating:       return "figure.skating"
        case .rowing:        return "figure.rowing"
        case .dancing:       return "figure.dance"
        case .martialArts:   return "figure.martial.arts"
        case .jumpRope:      return "figure.jumprope"
        case .hiking:        return "figure.hiking"
        case .hiit:          return "bolt.heart.fill"
        }
    }

    func estimatedKcal(minutes: Int) -> Double {
        kcalPerHour * Double(minutes) / 60.0
    }
}

// MARK: - App Limits

@Model final class AppLimits {
    var kcalTarget: Double = 2255
    var proteinTarget: Double = 200
    var carbsTarget: Double = 300
    var fatTarget: Double = 70
    var fiberTarget: Double = 30
    var sugarTarget: Double = 50
    var saturatedFatTarget: Double = 20
    var saltTarget: Double = 6
    var stepsTarget: Int = 10000
    var weightTarget: Double = 85
    var waterTarget: Double = 2.0
    var startDate: Date = Date()

    init() {}
}

// MARK: - User Profile

enum Sex: String, Codable, CaseIterable {
    case male         = "Maschio"
    case female       = "Femmina"
    case notSpecified = "Non specificato"
}

@Model final class UserProfile {
    var heightCm: Double? = nil
    var birthDate: Date? = nil
    var sex: Sex = Sex.notSpecified

    init() {}
}

// MARK: - BMR (Mifflin-St Jeor)

func calculateBMR(weightKg: Double, heightCm: Double, ageYears: Int, sex: Sex) -> Double {
    guard weightKg > 0, heightCm > 0, ageYears > 0 else { return 0 }
    switch sex {
    case .male:
        return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) + 5
    case .female:
        return (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) - 161
    case .notSpecified:
        let m = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) + 5
        let f = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(ageYears)) - 161
        return (m + f) / 2.0
    }
}

// MARK: - Target History

@Model final class TargetHistory {
    var effectiveDate: Date = Date()
    var kcalTarget: Double = 2255
    var proteinTarget: Double = 200
    var carbsTarget: Double = 300
    var fatTarget: Double = 70
    var fiberTarget: Double = 30
    var sugarTarget: Double = 50
    var saturatedFatTarget: Double = 20
    var saltTarget: Double = 6
    var stepsTarget: Int = 10000
    var weightTarget: Double = 85

    init() {}

    init(effectiveDate: Date, from limits: AppLimits) {
        self.effectiveDate      = effectiveDate
        self.kcalTarget         = limits.kcalTarget
        self.proteinTarget      = limits.proteinTarget
        self.carbsTarget        = limits.carbsTarget
        self.fatTarget          = limits.fatTarget
        self.fiberTarget        = limits.fiberTarget
        self.sugarTarget        = limits.sugarTarget
        self.saturatedFatTarget = limits.saturatedFatTarget
        self.saltTarget         = limits.saltTarget
        self.stepsTarget        = limits.stepsTarget
        self.weightTarget       = limits.weightTarget
    }
}

// MARK: - Medicine

@Model final class Medicine {
    var stableId: String = ""
    var name: String = ""
    var category: String = "Farmaco"
    var isDaily: Bool = true
    var useTime: Bool = false
    var timingPhase: String = "Mattina"
    var timingHour: Int = 8
    var timingMinute: Int = 0
    var createdAt: Date = Date()

    init(name: String, category: String, isDaily: Bool, useTime: Bool,
         timingPhase: String, timingHour: Int, timingMinute: Int) {
        self.stableId = UUID().uuidString
        self.name = name
        self.category = category
        self.isDaily = isDaily
        self.useTime = useTime
        self.timingPhase = timingPhase
        self.timingHour = timingHour
        self.timingMinute = timingMinute
        self.createdAt = Date()
    }
}

@Model final class MedicineLog {
    var medicineStableId: String = ""
    var dayKey: String = ""
    var taken: Bool = false
    var date: Date = Date()

    init(medicineStableId: String, dayKey: String, taken: Bool) {
        self.medicineStableId = medicineStableId
        self.dayKey = dayKey
        self.taken = taken
        self.date = Date()
    }
}

// MARK: - Date Helpers

extension Date {
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMM"
        return f
    }()

    var dateKey: String { Date.keyFormatter.string(from: self) }

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
        Date.displayFormatter.string(from: self).capitalized
    }
}
