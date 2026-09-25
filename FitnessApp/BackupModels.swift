import Foundation

// Formato del file di backup, indipendente da SwiftData e SwiftUI: contiene solo
// tipi Codable puri, così il formato resta verificabile e leggibile a parte.

// MARK: - Codable structs per export/import

struct BackupData: Codable {
    var version: Int = 6
    var exportDate: Date = Date()
    var foods: [FoodBackup]
    var entries: [EntryBackup]
    var logs: [LogBackup]
    var limits: LimitsBackup?
    var sports: [SportBackup]?
    var userProfile: UserProfileBackup?
    var targetHistory: [TargetHistoryBackup]?
    var customMeals: [CustomMealBackup]?
    var exercises: [ExerciseBackup]?
    var workoutTemplates: [WorkoutTemplateBackup]?
    var workoutSessions: [WorkoutSessionBackup]?
    var runSessions: [RunSessionBackup]?
    var jumpRopeSessions: [JumpRopeSessionBackup]?
    // Aggiunti nella versione 6 — restano opzionali per leggere i backup più vecchi.
    var waterEntries: [WaterBackup]?
    var medicines: [MedicineBackup]?
    var medicineLogs: [MedicineLogBackup]?
}

struct WaterBackup: Codable {
    var dayKey: String; var liters: Double; var date: Date
}

struct MedicineBackup: Codable {
    var stableId: String
    var name: String; var category: String; var isDaily: Bool
    var notificationEnabled: Bool; var notificationHour: Int; var notificationMinute: Int
    var createdAt: Date
    var doses: [MedicineDoseBackup]
}

struct MedicineDoseBackup: Codable {
    var stableId: String
    var quantity: Int; var useTime: Bool
    var timingPhase: String; var timingHour: Int; var timingMinute: Int
    var sortOrder: Int
}

struct MedicineLogBackup: Codable {
    var doseStableId: String; var dayKey: String; var taken: Bool; var date: Date
}

struct JumpRopeSessionBackup: Codable {
    var date: Date; var dayKey: String
    var rounds: Int; var plannedRounds: Int
    var workSeconds: Int; var restSeconds: Int
    var activeSeconds: Double; var kcalBurned: Double; var jumps: Int
    var stableId: String?
}

struct RunSessionBackup: Codable {
    var date: Date; var dayKey: String
    var distanceMeters: Double; var durationSeconds: Double; var kcalBurned: Double
    var splitSeconds: [Double]
    var route: [RoutePoint]
    var avgHeartRate: Double?; var maxHeartRate: Double?
    var heartRate: [HRPoint]?
    var stableId: String?
}

struct ExerciseBackup: Codable {
    var name: String; var muscleGroup: String; var notes: String
    var defaultSets: Int?; var defaultReps: Int?
    var defaultWeight: Double?; var defaultRestSeconds: Int?
}

struct TemplateExerciseSetBackup: Codable {
    var reps: Int; var weight: Double; var restSeconds: Int; var orderIndex: Int
}

struct TemplateExerciseBackup: Codable {
    var exerciseName: String; var muscleGroup: String; var orderIndex: Int
    var sets: Int?; var reps: Int?; var weight: Double?; var restSeconds: Int?
    var templateSets: [TemplateExerciseSetBackup]?
}

struct WorkoutTemplateBackup: Codable {
    var name: String; var exerciseNames: [String]
    var templateExercises: [TemplateExerciseBackup]?
}

struct WorkoutSessionBackup: Codable {
    var date: Date; var dayKey: String; var templateName: String; var durationMinutes: Int
    var entries: [WorkoutEntryBackup]
}

struct WorkoutEntryBackup: Codable {
    var exerciseName: String; var exerciseMuscleGroup: String; var orderIndex: Int
    var sets: [WorkoutSetBackup]
}

struct WorkoutSetBackup: Codable {
    var reps: Int; var weight: Double; var completed: Bool; var restSeconds: Int; var orderIndex: Int
}

struct CustomMealBackup: Codable {
    var name: String; var portions: Double
    var ingredients: [CustomMealIngredientBackup]
    var totalWeight: Double?
}

struct CustomMealIngredientBackup: Codable {
    var foodName: String; var grams: Double
    var kcal: Double; var protein: Double; var carbs: Double; var fat: Double
    var fiber: Double; var sugar: Double; var saturatedFat: Double; var salt: Double
}

struct FoodBackup: Codable {
    var name: String
    var kcal: Double; var protein: Double; var carbs: Double; var fat: Double
    var fiber: Double; var sugar: Double; var saturatedFat: Double; var salt: Double
    var portionName: String?; var portionGrams: Double?
    var isFavorite: Bool?
}

struct EntryBackup: Codable {
    var date: Date; var dayKey: String; var meal: String; var grams: Double
    var foodName: String
    var kcal: Double; var protein: Double; var carbs: Double; var fat: Double
    var fiber: Double; var sugar: Double; var saturatedFat: Double; var salt: Double
}

struct LogBackup: Codable {
    var dateKey: String; var weight: Double?; var steps: Int; var gymColor: String
    var basalCaloriesBurned: Double?  // opzionale per compatibilità backup precedenti
    /// Energia attiva letta da Apple Health: senza questa il calcolo delle calorie
    /// bruciate dei giorni passati ripartiva dalla sola stima sui passi.
    var activeCaloriesBurned: Double?
}

struct LimitsBackup: Codable {
    var kcalTarget: Double; var proteinTarget: Double; var carbsTarget: Double
    var fatTarget: Double; var fiberTarget: Double; var sugarTarget: Double
    var saturatedFatTarget: Double; var saltTarget: Double
    var stepsTarget: Int; var weightTarget: Double; var startDate: Date
    var macroInputMode: String?
    var weeklyRunKmTarget: Double?
    var waterTarget: Double?
    var targetWeight: Double?
    var targetDate: Date?
    // Focus calorie
    var mealBudgetsEnabled: Bool?
    var overBudgetWarningEnabled: Bool?
    var breakfastPct: Double?
    var lunchPct: Double?
    var dinnerPct: Double?
    var snackPct: Double?
}

struct SportBackup: Codable {
    var dayKey: String; var sportName: String; var durationMinutes: Int; var kcalBurned: Double
    var autoTracked: Bool?; var sourceId: String?
}

struct UserProfileBackup: Codable {
    var heightCm: Double?
    var birthDate: Date?
    var sex: String
}

struct TargetHistoryBackup: Codable {
    var effectiveDate: Date
    var kcalTarget: Double; var proteinTarget: Double; var carbsTarget: Double
    var fatTarget: Double; var fiberTarget: Double; var sugarTarget: Double
    var saturatedFatTarget: Double; var saltTarget: Double
    var stepsTarget: Int; var weightTarget: Double
}
// MARK: - Riepilogo leggibile

extension BackupData {
    /// Righe "12 alimenti", "8 allenamenti"… mostrate dopo export e import, così è
    /// sempre visibile che cosa è finito davvero nel file.
    var summaryLines: [String] {
        var lines: [String] = []
        func add(_ count: Int, _ singular: String, _ plural: String) {
            guard count > 0 else { return }
            lines.append("\(count) \(count == 1 ? singular : plural)")
        }
        add(foods.count, "alimento", "alimenti")
        add(entries.count, "voce di diario", "voci di diario")
        add(logs.count, "giorno registrato", "giorni registrati")
        add(customMeals?.count ?? 0, "piatto", "piatti")
        add(workoutTemplates?.count ?? 0, "scheda", "schede")
        add(exercises?.count ?? 0, "esercizio", "esercizi")
        add(workoutSessions?.count ?? 0, "allenamento", "allenamenti")
        add(runSessions?.count ?? 0, "corsa", "corse")
        add(jumpRopeSessions?.count ?? 0, "sessione corda", "sessioni corda")
        add(sports?.count ?? 0, "attività", "attività")
        add(waterEntries?.count ?? 0, "bicchiere d'acqua", "registrazioni acqua")
        add(medicines?.count ?? 0, "farmaco", "farmaci")
        add(targetHistory?.count ?? 0, "storico obiettivi", "storici obiettivi")
        return lines
    }

    var summaryText: String {
        summaryLines.isEmpty ? "Nessun dato da salvare." : summaryLines.joined(separator: " · ")
    }
}

