import SwiftData
import Foundation

// MARK: - Schema V1

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        SchemaV1.FoodItem.self, SchemaV1.FoodEntry.self,
        SchemaV1.DayLog.self, SchemaV1.AppLimits.self
    ]

    @Model final class FoodItem {
        var name: String
        var kcalPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var fiberPer100g: Double
        var sugarPer100g: Double
        var saturatedFatPer100g: Double
        init(name: String, kcalPer100g: Double, proteinPer100g: Double,
             carbsPer100g: Double, fatPer100g: Double, fiberPer100g: Double,
             sugarPer100g: Double, saturatedFatPer100g: Double) {
            self.name = name; self.kcalPer100g = kcalPer100g
            self.proteinPer100g = proteinPer100g; self.carbsPer100g = carbsPer100g
            self.fatPer100g = fatPer100g; self.fiberPer100g = fiberPer100g
            self.sugarPer100g = sugarPer100g; self.saturatedFatPer100g = saturatedFatPer100g
        }
    }

    @Model final class FoodEntry {
        var date: Date
        var dayKey: String
        var meal: String
        var grams: Double
        var foodName: String
        var kcalSnapshot: Double
        var proteinSnapshot: Double
        var carbsSnapshot: Double
        var fatSnapshot: Double
        var fiberSnapshot: Double
        var sugarSnapshot: Double
        var saturatedFatSnapshot: Double
        init(date: Date, dayKey: String, meal: String, grams: Double, foodName: String,
             kcalSnapshot: Double, proteinSnapshot: Double, carbsSnapshot: Double,
             fatSnapshot: Double, fiberSnapshot: Double, sugarSnapshot: Double,
             saturatedFatSnapshot: Double) {
            self.date = date; self.dayKey = dayKey; self.meal = meal; self.grams = grams
            self.foodName = foodName; self.kcalSnapshot = kcalSnapshot
            self.proteinSnapshot = proteinSnapshot; self.carbsSnapshot = carbsSnapshot
            self.fatSnapshot = fatSnapshot; self.fiberSnapshot = fiberSnapshot
            self.sugarSnapshot = sugarSnapshot; self.saturatedFatSnapshot = saturatedFatSnapshot
        }
    }

    @Model final class DayLog {
        @Attribute(.unique) var dateKey: String
        var weight: Double?
        var steps: Int
        var gymColor: String
        init(dateKey: String, weight: Double? = nil, steps: Int = 0, gymColor: String = "rest") {
            self.dateKey = dateKey; self.weight = weight
            self.steps = steps; self.gymColor = gymColor
        }
    }

    @Model final class AppLimits {
        var kcalTarget: Double
        var proteinTarget: Double
        var carbsTarget: Double
        var fatTarget: Double
        var fiberTarget: Double
        var sugarTarget: Double
        var saturatedFatTarget: Double
        var stepsTarget: Int
        var weightTarget: Double
        init() {
            kcalTarget = 2255; proteinTarget = 200; carbsTarget = 300
            fatTarget = 70; fiberTarget = 30; sugarTarget = 50
            saturatedFatTarget = 20; stepsTarget = 10000; weightTarget = 85
        }
    }
}

// MARK: - Schema V2

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        SchemaV2.FoodItem.self, SchemaV2.FoodEntry.self,
        SchemaV2.DayLog.self, SchemaV2.AppLimits.self
    ]

    @Model final class FoodItem {
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
        init(name: String, kcalPer100g: Double, proteinPer100g: Double,
             carbsPer100g: Double, fatPer100g: Double, fiberPer100g: Double,
             sugarPer100g: Double, saturatedFatPer100g: Double,
             portionName: String? = nil, portionGrams: Double? = nil) {
            self.name = name; self.kcalPer100g = kcalPer100g
            self.proteinPer100g = proteinPer100g; self.carbsPer100g = carbsPer100g
            self.fatPer100g = fatPer100g; self.fiberPer100g = fiberPer100g
            self.sugarPer100g = sugarPer100g; self.saturatedFatPer100g = saturatedFatPer100g
            self.portionName = portionName; self.portionGrams = portionGrams
        }
    }

    @Model final class FoodEntry {
        var date: Date
        var dayKey: String
        var meal: String
        var grams: Double
        var foodName: String
        var kcalSnapshot: Double
        var proteinSnapshot: Double
        var carbsSnapshot: Double
        var fatSnapshot: Double
        var fiberSnapshot: Double
        var sugarSnapshot: Double
        var saturatedFatSnapshot: Double
        init(date: Date, dayKey: String, meal: String, grams: Double, foodName: String,
             kcalSnapshot: Double, proteinSnapshot: Double, carbsSnapshot: Double,
             fatSnapshot: Double, fiberSnapshot: Double, sugarSnapshot: Double,
             saturatedFatSnapshot: Double) {
            self.date = date; self.dayKey = dayKey; self.meal = meal; self.grams = grams
            self.foodName = foodName; self.kcalSnapshot = kcalSnapshot
            self.proteinSnapshot = proteinSnapshot; self.carbsSnapshot = carbsSnapshot
            self.fatSnapshot = fatSnapshot; self.fiberSnapshot = fiberSnapshot
            self.sugarSnapshot = sugarSnapshot; self.saturatedFatSnapshot = saturatedFatSnapshot
        }
    }

    @Model final class DayLog {
        @Attribute(.unique) var dateKey: String
        var weight: Double?
        var steps: Int
        var gymColor: String
        init(dateKey: String, weight: Double? = nil, steps: Int = 0, gymColor: String = "rest") {
            self.dateKey = dateKey; self.weight = weight
            self.steps = steps; self.gymColor = gymColor
        }
    }

    @Model final class AppLimits {
        var kcalTarget: Double
        var proteinTarget: Double
        var carbsTarget: Double
        var fatTarget: Double
        var fiberTarget: Double
        var sugarTarget: Double
        var saturatedFatTarget: Double
        var stepsTarget: Int
        var weightTarget: Double
        var startDate: Date
        init() {
            kcalTarget = 2255; proteinTarget = 200; carbsTarget = 300
            fatTarget = 70; fiberTarget = 30; sugarTarget = 50
            saturatedFatTarget = 20; stepsTarget = 10000; weightTarget = 85
            startDate = Calendar.current.startOfDay(for: Date())
        }
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [SchemaV1.self, SchemaV2.self]
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}

// MARK: - Come aggiungere SchemaV3 in futuro
//
// 1. Copia SchemaV2 e rinominalo SchemaV3
// 2. Aggiungi le nuove proprietà con default o come opzionali
// 3. Aggiungi SchemaV3.self all'array `schemas`
// 4. Aggiungi .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
// 5. Non modificare mai V1 o V2
