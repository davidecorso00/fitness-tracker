import Foundation

// Verifica del formato di backup: round-trip completo e lettura dei file v5 vecchi.
// RoutePoint / HRPoint sono estratti da Models.swift a build time, così non divergono.

var failures = 0

func check(_ label: String, _ condition: Bool) {
    if condition {
        print("  ok   \(label)")
    } else {
        print("  FAIL \(label)")
        failures += 1
    }
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let now = Date()

// ── Pezzi del backup, costruiti a parte per non far esplodere il type-checker ──

let foods = [FoodBackup(name: "Pollo", kcal: 165, protein: 31, carbs: 0, fat: 3,
                        fiber: 0, sugar: 0, saturatedFat: 0.9, salt: 0.1,
                        portionName: "petto", portionGrams: 150)]

let entries = [EntryBackup(date: now, dayKey: "2026-08-16", meal: "Pranzo", grams: 200,
                           foodName: "Pollo", kcal: 330, protein: 62, carbs: 0, fat: 6,
                           fiber: 0, sugar: 0, saturatedFat: 1.8, salt: 0.2)]

let logs = [LogBackup(dateKey: "2026-08-16", weight: 84.2, steps: 9120, gymColor: "green",
                      basalCaloriesBurned: nil, activeCaloriesBurned: 612)]

let limits = LimitsBackup(kcalTarget: 2000, proteinTarget: 180, carbsTarget: 150,
                          fatTarget: 75, fiberTarget: 30, sugarTarget: 50,
                          saturatedFatTarget: 20, saltTarget: 6, stepsTarget: 10000,
                          weightTarget: 85, startDate: now, macroInputMode: "grams",
                          weeklyRunKmTarget: 20, waterTarget: 2.5,
                          targetWeight: 80, targetDate: now)

let sports = [SportBackup(dayKey: "2026-08-16", sportName: "Corsa", durationMinutes: 42,
                          kcalBurned: 430, autoTracked: true, sourceId: "run-uuid-1")]

let profile = UserProfileBackup(heightCm: 180, birthDate: now, sex: "Maschio")

let history = [TargetHistoryBackup(effectiveDate: now, kcalTarget: 2000,
                                   proteinTarget: 180, carbsTarget: 150, fatTarget: 75,
                                   fiberTarget: 30, sugarTarget: 50, saturatedFatTarget: 20,
                                   saltTarget: 6, stepsTarget: 10000, weightTarget: 85)]

let mealIngredient = CustomMealIngredientBackup(foodName: "Pasta", grams: 160,
                                                kcal: 362, protein: 13, carbs: 75, fat: 1,
                                                fiber: 3, sugar: 3, saturatedFat: 0.2, salt: 0)
let customMeals = [CustomMealBackup(name: "Pasta al tonno", portions: 2,
                                    ingredients: [mealIngredient])]

let exercises = [ExerciseBackup(name: "Panca Piana", muscleGroup: "Petto", notes: "",
                                defaultSets: 4, defaultReps: 8,
                                defaultWeight: 70, defaultRestSeconds: 120)]

let templateSet = TemplateExerciseSetBackup(reps: 8, weight: 70, restSeconds: 120, orderIndex: 0)
let templateExercise = TemplateExerciseBackup(exerciseName: "Panca Piana", muscleGroup: "Petto",
                                              orderIndex: 0, sets: 4, reps: 8, weight: 70,
                                              restSeconds: 120, templateSets: [templateSet])
let templates = [WorkoutTemplateBackup(name: "Giorno A", exerciseNames: ["Panca Piana"],
                                       templateExercises: [templateExercise])]

let workoutSet = WorkoutSetBackup(reps: 8, weight: 70, completed: true,
                                  restSeconds: 120, orderIndex: 0)
let workoutEntry = WorkoutEntryBackup(exerciseName: "Panca Piana",
                                      exerciseMuscleGroup: "Petto", orderIndex: 0,
                                      sets: [workoutSet])
let workoutSessions = [WorkoutSessionBackup(date: now, dayKey: "2026-08-16",
                                            templateName: "Giorno A", durationMinutes: 63,
                                            entries: [workoutEntry])]

let runs = [RunSessionBackup(date: now, dayKey: "2026-08-16",
                             distanceMeters: 8300, durationSeconds: 2520, kcalBurned: 610,
                             splitSeconds: [303, 298, 305],
                             route: [RoutePoint(lat: 46.01, lon: 8.95, t: 0, seg: 0)],
                             avgHeartRate: 152, maxHeartRate: 178,
                             heartRate: [HRPoint(t: 0, bpm: 120)], stableId: "run-uuid-1")]

let ropes = [JumpRopeSessionBackup(date: now, dayKey: "2026-08-16",
                                   rounds: 6, plannedRounds: 6, workSeconds: 60,
                                   restSeconds: 30, activeSeconds: 545, kcalBurned: 190,
                                   jumps: 720, stableId: "rope-uuid-1")]

let waters = [WaterBackup(dayKey: "2026-08-16", liters: 0.5, date: now)]

let dose = MedicineDoseBackup(stableId: "dose-1", quantity: 1, useTime: false,
                              timingPhase: "Sera", timingHour: 20, timingMinute: 0, sortOrder: 0)
let medicines = [MedicineBackup(stableId: "med-1", name: "Vitamina D",
                                category: "Integratore", isDaily: true,
                                notificationEnabled: true, notificationHour: 20,
                                notificationMinute: 30, createdAt: now, doses: [dose])]
let medLogs = [MedicineLogBackup(doseStableId: "dose-1", dayKey: "2026-08-16",
                                 taken: true, date: now)]

let full = BackupData(
    foods: foods, entries: entries, logs: logs, limits: limits, sports: sports,
    userProfile: profile, targetHistory: history, customMeals: customMeals,
    exercises: exercises, workoutTemplates: templates, workoutSessions: workoutSessions,
    runSessions: runs, jumpRopeSessions: ropes, waterEntries: waters,
    medicines: medicines, medicineLogs: medLogs)

// ── 1. Round-trip v6 ──────────────────────────────────────────────────────────

print("\n1. Round-trip v6 (esporta → rilegge)")
let data = try encoder.encode(full)
let back = try decoder.decode(BackupData.self, from: data)

check("versione 6", back.version == 6)
check("alimenti", back.foods.first?.name == "Pollo")
check("voci diario", back.entries.count == 1)
check("calorie attive del giorno", back.logs.first?.activeCaloriesBurned == 612)
check("piatti personalizzati", back.customMeals?.count == 1)
check("ingredienti del piatto", back.customMeals?.first?.ingredients.first?.foodName == "Pasta")
check("schede", back.workoutTemplates?.count == 1)
check("serie nella scheda", back.workoutTemplates?.first?.templateExercises?.first?.templateSets?.count == 1)
check("sessioni palestra", back.workoutSessions?.count == 1)
check("esercizi nella sessione", back.workoutSessions?.first?.entries.count == 1)
check("serie nella sessione", back.workoutSessions?.first?.entries.first?.sets.first?.reps == 8)
check("corse", back.runSessions?.count == 1)
check("percorso GPS", back.runSessions?.first?.route.count == 1)
check("battito corsa", back.runSessions?.first?.heartRate?.count == 1)
check("stableId corsa", back.runSessions?.first?.stableId == "run-uuid-1")
check("sessioni corda", back.jumpRopeSessions?.first?.jumps == 720)
check("acqua", back.waterEntries?.first?.liters == 0.5)
check("farmaci", back.medicines?.first?.name == "Vitamina D")
check("dosi farmaco", back.medicines?.first?.doses.first?.stableId == "dose-1")
check("log farmaci", back.medicineLogs?.first?.doseStableId == "dose-1")
check("obiettivo peso", back.limits?.targetWeight == 80)
check("data obiettivo", back.limits?.targetDate != nil)
check("target acqua", back.limits?.waterTarget == 2.5)
check("sport autoTracked", back.sports?.first?.autoTracked == true)
check("sport sourceId", back.sports?.first?.sourceId == "run-uuid-1")

// ── 2. Retrocompatibilità con i backup v5 ─────────────────────────────────────

print("\n2. Lettura di un backup v5 (senza i campi nuovi)")
let v5 = """
{
  "version": 5,
  "exportDate": "2026-05-01T10:00:00Z",
  "foods": [{"name":"Pasta","kcal":362,"protein":13,"carbs":75,"fat":1,
             "fiber":3,"sugar":3,"saturatedFat":0.2,"salt":0.1}],
  "entries": [{"date":"2026-05-01T12:00:00Z","dayKey":"2026-05-01","meal":"Pranzo",
               "grams":100,"foodName":"Pasta","kcal":362,"protein":13,"carbs":75,
               "fat":1,"fiber":3,"sugar":3,"saturatedFat":0.2,"salt":0.1}],
  "logs": [{"dateKey":"2026-05-01","steps":8000,"gymColor":"rest"}],
  "limits": {"kcalTarget":2000,"proteinTarget":180,"carbsTarget":150,"fatTarget":75,
             "fiberTarget":30,"sugarTarget":50,"saturatedFatTarget":20,"saltTarget":6,
             "stepsTarget":10000,"weightTarget":85,"startDate":"2026-03-16T00:00:00Z"},
  "workoutSessions": [{"date":"2026-05-01T18:00:00Z","dayKey":"2026-05-01",
                       "templateName":"Giorno A","durationMinutes":55,"entries":[]}]
}
"""
let old = try decoder.decode(BackupData.self, from: Data(v5.utf8))
check("versione 5 letta", old.version == 5)
check("alimenti v5", old.foods.count == 1)
check("sessione palestra v5", old.workoutSessions?.count == 1)
check("campi nuovi assenti → nil", old.waterEntries == nil && old.medicines == nil)
check("peso assente → nil", old.logs.first?.weight == nil)
check("calorie attive assenti → nil", old.logs.first?.activeCaloriesBurned == nil)
check("targetWeight assente → nil", old.limits?.targetWeight == nil)

// ── 3. Lo spazio "Un attimo" non esce dal telefono ────────────────────────────

print("\n3. I dati di \"Un attimo\" restano fuori dal backup")

// Frasi personali, note su cosa stava succedendo e foto sono i contenuti piu'
// sensibili dell'app: non devono finire in un file JSON condivisibile.
// Il controllo e' sul formato, non sull'intenzione: se qualcuno aggiungesse
// per distrazione un campo Pausa a BackupData, questo test lo ferma.
let json = String(data: try encoder.encode(full), encoding: .utf8) ?? ""
for vietato in ["pausa", "Pausa", "frase", "marker", "attimo"] {
    check("il backup non contiene '\(vietato)'", !json.contains(vietato))
}

let campiBackup = Mirror(reflecting: full).children.compactMap(\.label)
check("BackupData non ha campi della sezione Pausa",
      !campiBackup.contains { $0.lowercased().contains("pausa") })
print("  campi esportati: \(campiBackup.joined(separator: ", "))")

// ── 4. Riepilogo mostrato all'utente ──────────────────────────────────────────

print("\n4. Riepilogo dopo export/import")
let summary = full.summaryText
print("  → \(summary)")
for atteso in ["piatto", "allenamento", "corsa", "farmaco", "scheda", "acqua", "sessione corda"] {
    check("il riepilogo cita '\(atteso)'", summary.contains(atteso))
}

// ── Esito ─────────────────────────────────────────────────────────────────────

print("")
if failures == 0 {
    print("TUTTI I CONTROLLI SUPERATI")
} else {
    print("\(failures) CONTROLLI FALLITI")
    exit(1)
}
