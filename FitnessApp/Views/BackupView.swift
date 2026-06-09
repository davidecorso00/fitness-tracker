import SwiftUI
import SwiftData

// MARK: - Codable structs per export/import

struct BackupData: Codable {
    var version: Int = 4
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
}

struct LimitsBackup: Codable {
    var kcalTarget: Double; var proteinTarget: Double; var carbsTarget: Double
    var fatTarget: Double; var fiberTarget: Double; var sugarTarget: Double
    var saturatedFatTarget: Double; var saltTarget: Double
    var stepsTarget: Int; var weightTarget: Double; var startDate: Date
    var macroInputMode: String?
}

struct SportBackup: Codable {
    var dayKey: String; var sportName: String; var durationMinutes: Int; var kcalBurned: Double
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

// MARK: - Backup Manager

@MainActor
final class BackupManager {

    static func export(context: ModelContext) throws -> Data {
        let foods   = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let logs    = (try? context.fetch(FetchDescriptor<DayLog>())) ?? []
        let limits  = (try? context.fetch(FetchDescriptor<AppLimits>()))?.first
        let sports  = (try? context.fetch(FetchDescriptor<SportEntry>())) ?? []
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let history = (try? context.fetch(FetchDescriptor<TargetHistory>(
            sortBy: [SortDescriptor(\.effectiveDate)]
        ))) ?? []
        let cMeals  = (try? context.fetch(FetchDescriptor<CustomMeal>())) ?? []
        let exs     = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let wTemplates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let wSessions  = (try? context.fetch(FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []

        let backup = BackupData(
            foods: foods.map {
                FoodBackup(name: $0.name, kcal: $0.kcalPer100g, protein: $0.proteinPer100g,
                    carbs: $0.carbsPer100g, fat: $0.fatPer100g, fiber: $0.fiberPer100g,
                    sugar: $0.sugarPer100g, saturatedFat: $0.saturatedFatPer100g,
                    salt: $0.saltPer100g, portionName: $0.portionName, portionGrams: $0.portionGrams)
            },
            entries: entries.map {
                EntryBackup(date: $0.date, dayKey: $0.dayKey, meal: $0.meal.rawValue,
                    grams: $0.grams, foodName: $0.foodName,
                    kcal: $0.kcalSnapshot, protein: $0.proteinSnapshot, carbs: $0.carbsSnapshot,
                    fat: $0.fatSnapshot, fiber: $0.fiberSnapshot, sugar: $0.sugarSnapshot,
                    saturatedFat: $0.saturatedFatSnapshot, salt: $0.saltSnapshot)
            },
            logs: logs.map {
                LogBackup(dateKey: $0.dateKey, weight: $0.weight, steps: $0.steps,
                    gymColor: $0.gymColor.rawValue,
                    basalCaloriesBurned: $0.basalCaloriesBurned > 0 ? $0.basalCaloriesBurned : nil)
            },
            limits: limits.map {
                LimitsBackup(kcalTarget: $0.kcalTarget, proteinTarget: $0.proteinTarget,
                    carbsTarget: $0.carbsTarget, fatTarget: $0.fatTarget, fiberTarget: $0.fiberTarget,
                    sugarTarget: $0.sugarTarget, saturatedFatTarget: $0.saturatedFatTarget,
                    saltTarget: $0.saltTarget, stepsTarget: $0.stepsTarget,
                    weightTarget: $0.weightTarget, startDate: $0.startDate,
                    macroInputMode: $0.macroInputMode)
            },
            sports: sports.map {
                SportBackup(dayKey: $0.dayKey, sportName: $0.sportName,
                    durationMinutes: $0.durationMinutes, kcalBurned: $0.kcalBurned)
            },
            userProfile: profile.map {
                UserProfileBackup(heightCm: $0.heightCm, birthDate: $0.birthDate, sex: $0.sex.rawValue)
            },
            targetHistory: history.map {
                TargetHistoryBackup(effectiveDate: $0.effectiveDate,
                    kcalTarget: $0.kcalTarget, proteinTarget: $0.proteinTarget,
                    carbsTarget: $0.carbsTarget, fatTarget: $0.fatTarget,
                    fiberTarget: $0.fiberTarget, sugarTarget: $0.sugarTarget,
                    saturatedFatTarget: $0.saturatedFatTarget, saltTarget: $0.saltTarget,
                    stepsTarget: $0.stepsTarget, weightTarget: $0.weightTarget)
            },
            customMeals: cMeals.map { cm in
                CustomMealBackup(name: cm.name, portions: cm.portions,
                    ingredients: cm.ingredients.map { ing in
                        CustomMealIngredientBackup(foodName: ing.foodName, grams: ing.grams,
                            kcal: ing.kcalPer100g, protein: ing.proteinPer100g, carbs: ing.carbsPer100g,
                            fat: ing.fatPer100g, fiber: ing.fiberPer100g, sugar: ing.sugarPer100g,
                            saturatedFat: ing.saturatedFatPer100g, salt: ing.saltPer100g)
                    })
            },
            exercises: exs.map { ExerciseBackup(name: $0.name, muscleGroup: $0.muscleGroup, notes: $0.notes, defaultSets: $0.defaultSets, defaultReps: $0.defaultReps, defaultWeight: $0.defaultWeight, defaultRestSeconds: $0.defaultRestSeconds) },
            workoutTemplates: wTemplates.map { t in
                let teBackups = t.templateExercises.sorted { $0.orderIndex < $1.orderIndex }.map { te in
                    let tsBackups = te.templateSets.sorted { $0.orderIndex < $1.orderIndex }.map { ts in
                        TemplateExerciseSetBackup(reps: ts.reps, weight: ts.weight, restSeconds: ts.restSeconds, orderIndex: ts.orderIndex)
                    }
                    return TemplateExerciseBackup(exerciseName: te.exerciseName, muscleGroup: te.muscleGroup,
                        orderIndex: te.orderIndex, sets: te.sets, reps: te.reps,
                        weight: te.weight, restSeconds: te.restSeconds, templateSets: tsBackups)
                }
                return WorkoutTemplateBackup(name: t.name, exerciseNames: t.exerciseNames, templateExercises: teBackups)
            },
            workoutSessions: wSessions.map { sess in
                WorkoutSessionBackup(
                    date: sess.date, dayKey: sess.dayKey,
                    templateName: sess.templateName, durationMinutes: sess.durationMinutes,
                    entries: sess.entries.sorted { $0.orderIndex < $1.orderIndex }.map { entry in
                        WorkoutEntryBackup(
                            exerciseName: entry.exerciseName,
                            exerciseMuscleGroup: entry.exerciseMuscleGroup,
                            orderIndex: entry.orderIndex,
                            sets: entry.sets.sorted { $0.orderIndex < $1.orderIndex }.map { ws in
                                WorkoutSetBackup(reps: ws.reps, weight: ws.weight, completed: ws.completed,
                                                 restSeconds: ws.restSeconds, orderIndex: ws.orderIndex)
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(backup)
    }

    static func restore(from data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)

        try context.delete(model: FoodItem.self)
        try context.delete(model: FoodEntry.self)
        try context.delete(model: DayLog.self)
        try context.delete(model: AppLimits.self)
        try context.delete(model: SportEntry.self)
        try context.delete(model: UserProfile.self)
        try context.delete(model: TargetHistory.self)
        try context.delete(model: CustomMeal.self)
        try context.delete(model: CustomMealIngredient.self)
        try context.delete(model: Exercise.self)
        try context.delete(model: TemplateExerciseSet.self)
        try context.delete(model: TemplateExercise.self)
        try context.delete(model: WorkoutTemplate.self)
        try context.delete(model: WorkoutSession.self)
        try context.delete(model: WorkoutEntry.self)
        try context.delete(model: WorkoutSet.self)

        for f in backup.foods {
            context.insert(FoodItem(name: f.name, kcalPer100g: f.kcal, proteinPer100g: f.protein,
                carbsPer100g: f.carbs, fatPer100g: f.fat, fiberPer100g: f.fiber,
                sugarPer100g: f.sugar, saturatedFatPer100g: f.saturatedFat, saltPer100g: f.salt,
                portionName: f.portionName, portionGrams: f.portionGrams))
        }

        for e in backup.entries {
            let meal = MealType(rawValue: e.meal) ?? .snack
            let dummyFood = FoodItem(name: e.foodName, kcalPer100g: 0, proteinPer100g: 0,
                carbsPer100g: 0, fatPer100g: 0)
            let entry = FoodEntry(food: dummyFood, grams: e.grams, meal: meal, date: e.date)
            entry.kcalSnapshot = e.kcal; entry.proteinSnapshot = e.protein
            entry.carbsSnapshot = e.carbs; entry.fatSnapshot = e.fat
            entry.fiberSnapshot = e.fiber; entry.sugarSnapshot = e.sugar
            entry.saturatedFatSnapshot = e.saturatedFat; entry.saltSnapshot = e.salt
            context.insert(entry)
        }

        for l in backup.logs {
            let log = DayLog(dateKey: l.dateKey)
            log.weight   = l.weight
            log.steps    = l.steps
            log.gymColor = GymColor(rawValue: l.gymColor) ?? .rest
            log.basalCaloriesBurned = l.basalCaloriesBurned ?? 0
            context.insert(log)
        }

        if let l = backup.limits {
            let lim = AppLimits()
            lim.kcalTarget = l.kcalTarget; lim.proteinTarget = l.proteinTarget
            lim.carbsTarget = l.carbsTarget; lim.fatTarget = l.fatTarget
            lim.fiberTarget = l.fiberTarget; lim.sugarTarget = l.sugarTarget
            lim.saturatedFatTarget = l.saturatedFatTarget; lim.saltTarget = l.saltTarget
            lim.stepsTarget = l.stepsTarget; lim.weightTarget = l.weightTarget
            lim.startDate = l.startDate
            lim.macroInputMode = l.macroInputMode ?? "grams"
            context.insert(lim)
        }

        for s in backup.sports ?? [] {
            context.insert(SportEntry(dayKey: s.dayKey, sportName: s.sportName,
                durationMinutes: s.durationMinutes, kcalBurned: s.kcalBurned))
        }

        if let p = backup.userProfile {
            let prof = UserProfile()
            prof.heightCm  = p.heightCm
            prof.birthDate = p.birthDate
            prof.sex       = Sex(rawValue: p.sex) ?? .notSpecified
            context.insert(prof)
        }

        for t in backup.targetHistory ?? [] {
            let hist = TargetHistory()
            hist.effectiveDate      = t.effectiveDate
            hist.kcalTarget         = t.kcalTarget
            hist.proteinTarget      = t.proteinTarget
            hist.carbsTarget        = t.carbsTarget
            hist.fatTarget          = t.fatTarget
            hist.fiberTarget        = t.fiberTarget
            hist.sugarTarget        = t.sugarTarget
            hist.saturatedFatTarget = t.saturatedFatTarget
            hist.saltTarget         = t.saltTarget
            hist.stepsTarget        = t.stepsTarget
            hist.weightTarget       = t.weightTarget
            context.insert(hist)
        }

        for cm in backup.customMeals ?? [] {
            let meal = CustomMeal(); meal.name = cm.name; meal.portions = cm.portions
            context.insert(meal)
            for bi in cm.ingredients {
                let ing = CustomMealIngredient()
                ing.foodName = bi.foodName; ing.grams = bi.grams
                ing.kcalPer100g = bi.kcal; ing.proteinPer100g = bi.protein
                ing.carbsPer100g = bi.carbs; ing.fatPer100g = bi.fat
                ing.fiberPer100g = bi.fiber; ing.sugarPer100g = bi.sugar
                ing.saturatedFatPer100g = bi.saturatedFat; ing.saltPer100g = bi.salt
                ing.meal = meal; context.insert(ing)
                meal.ingredients.append(ing)
            }
        }

        for ex in backup.exercises ?? [] {
            let e = Exercise(name: ex.name, muscleGroup: ex.muscleGroup, notes: ex.notes)
            if let s = ex.defaultSets { e.defaultSets = s }
            if let r = ex.defaultReps { e.defaultReps = r }
            if let w = ex.defaultWeight { e.defaultWeight = w }
            if let rest = ex.defaultRestSeconds { e.defaultRestSeconds = rest }
            context.insert(e)
        }

        for t in backup.workoutTemplates ?? [] {
            let tmpl = WorkoutTemplate(name: t.name)
            tmpl.exerciseNames = t.exerciseNames
            context.insert(tmpl)
            let teList = t.templateExercises ?? []
            for te in teList {
                let newTE = TemplateExercise(exerciseName: te.exerciseName, muscleGroup: te.muscleGroup, orderIndex: te.orderIndex)
                if let s = te.sets { newTE.sets = s }
                if let r = te.reps { newTE.reps = r }
                if let w = te.weight { newTE.weight = w }
                if let rest = te.restSeconds { newTE.restSeconds = rest }
                newTE.template = tmpl
                context.insert(newTE)
                tmpl.templateExercises.append(newTE)
                for ts in te.templateSets ?? [] {
                    let newTS = TemplateExerciseSet(reps: ts.reps, weight: ts.weight, restSeconds: ts.restSeconds, orderIndex: ts.orderIndex)
                    newTS.templateExercise = newTE
                    context.insert(newTS)
                    newTE.templateSets.append(newTS)
                }
            }
        }

        for s in backup.workoutSessions ?? [] {
            let sess = WorkoutSession(date: s.date, templateName: s.templateName)
            sess.dayKey = s.dayKey; sess.durationMinutes = s.durationMinutes
            context.insert(sess)
            for e in s.entries {
                let entry = WorkoutEntry(exerciseName: e.exerciseName,
                                        exerciseMuscleGroup: e.exerciseMuscleGroup, orderIndex: e.orderIndex)
                entry.session = sess; context.insert(entry); sess.entries.append(entry)
                for ws in e.sets {
                    let wset = WorkoutSet(reps: ws.reps, weight: ws.weight, completed: ws.completed,
                                         restSeconds: ws.restSeconds, orderIndex: ws.orderIndex)
                    wset.entry = entry; context.insert(wset); entry.sets.append(wset)
                }
            }
        }

        try context.save()
    }
}

// MARK: - Backup View

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportData: Data?
    @State private var alertMsg = ""
    @State private var showAlert = false
    @State private var showRestoreConfirm = false
    @State private var pendingRestoreData: Data?

    var body: some View {
        VStack(spacing: 14) {
            HTCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Esporta backup")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Salva tutti i tuoi dati (alimenti, diario, peso, impostazioni) in un file JSON. Tienilo al sicuro prima di aggiornamenti importanti.")
                        .font(.system(size: 13)).foregroundColor(.muted)
                    Button { doExport() } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Esporta dati")
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.gymGreen).cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }

            HTCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Importa backup")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Ripristina i dati da un file JSON precedentemente esportato. Attenzione: i dati attuali verranno sostituiti.")
                        .font(.system(size: 13)).foregroundColor(.muted)
                    Button { showImporter = true } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Importa dati")
                        }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.gymOrange)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.gymOrange.opacity(0.15)).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gymOrange.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .fileExporter(
            isPresented: $showExporter,
            document: JSONDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: "fitness-backup-\(Date().dateKey)"
        ) { result in
            switch result {
            case .success: alertMsg = "Backup esportato con successo ✓"
            case .failure(let e): alertMsg = "Errore: \(e.localizedDescription)"
            }
            showAlert = true
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    pendingRestoreData = data
                    showRestoreConfirm = true
                }
            case .failure(let e):
                alertMsg = "Errore: \(e.localizedDescription)"
                showAlert = true
            }
        }
        .confirmationDialog("Sostituire i dati attuali con il backup?",
            isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Ripristina", role: .destructive) {
                if let data = pendingRestoreData { doRestore(data) }
            }
            Button("Annulla", role: .cancel) {}
        }
        .alert(alertMsg, isPresented: $showAlert) { Button("OK") {} }
    }

    private func doExport() {
        do {
            exportData = try BackupManager.export(context: context)
            showExporter = true
        } catch {
            alertMsg = "Errore durante l'export: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func doRestore(_ data: Data) {
        do {
            try BackupManager.restore(from: data, context: context)
            alertMsg = "Dati ripristinati con successo ✓"
        } catch {
            alertMsg = "Errore durante il ripristino: \(error.localizedDescription)"
        }
        showAlert = true
    }
}

// MARK: - FileDocument

import UniformTypeIdentifiers

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
