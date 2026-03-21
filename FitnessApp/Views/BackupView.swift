import SwiftUI
import SwiftData

// MARK: - Codable structs per export/import

struct BackupData: Codable {
    var version: Int = 1
    var exportDate: Date = Date()
    var foods: [FoodBackup]
    var entries: [EntryBackup]
    var logs: [LogBackup]
    var limits: LimitsBackup?
    var sports: [SportBackup]?
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
}

struct LimitsBackup: Codable {
    var kcalTarget: Double; var proteinTarget: Double; var carbsTarget: Double
    var fatTarget: Double; var fiberTarget: Double; var sugarTarget: Double
    var saturatedFatTarget: Double; var saltTarget: Double
    var stepsTarget: Int; var weightTarget: Double; var startDate: Date
}

struct SportBackup: Codable {
    var dayKey: String; var sportName: String; var durationMinutes: Int; var kcalBurned: Double
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
                LogBackup(dateKey: $0.dateKey, weight: $0.weight, steps: $0.steps, gymColor: $0.gymColor.rawValue)
            },
            limits: limits.map {
                LimitsBackup(kcalTarget: $0.kcalTarget, proteinTarget: $0.proteinTarget,
                    carbsTarget: $0.carbsTarget, fatTarget: $0.fatTarget, fiberTarget: $0.fiberTarget,
                    sugarTarget: $0.sugarTarget, saturatedFatTarget: $0.saturatedFatTarget,
                    saltTarget: $0.saltTarget, stepsTarget: $0.stepsTarget,
                    weightTarget: $0.weightTarget, startDate: $0.startDate)
            },
            sports: sports.map {
                SportBackup(dayKey: $0.dayKey, sportName: $0.sportName,
                    durationMinutes: $0.durationMinutes, kcalBurned: $0.kcalBurned)
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

        // Cancella tutto
        try context.delete(model: FoodItem.self)
        try context.delete(model: FoodEntry.self)
        try context.delete(model: DayLog.self)
        try context.delete(model: AppLimits.self)
        try context.delete(model: SportEntry.self)

        // Ripristina foods
        for f in backup.foods {
            context.insert(FoodItem(name: f.name, kcalPer100g: f.kcal, proteinPer100g: f.protein,
                carbsPer100g: f.carbs, fatPer100g: f.fat, fiberPer100g: f.fiber,
                sugarPer100g: f.sugar, saturatedFatPer100g: f.saturatedFat, saltPer100g: f.salt,
                portionName: f.portionName, portionGrams: f.portionGrams))
        }

        // Ripristina entries
        for e in backup.entries {
            let meal = MealType(rawValue: e.meal) ?? .snack
            let tempFood = FoodItem(name: e.foodName, kcalPer100g: e.kcal,
                proteinPer100g: e.protein, carbsPer100g: e.carbs, fatPer100g: e.fat,
                fiberPer100g: e.fiber, sugarPer100g: e.sugar,
                saturatedFatPer100g: e.saturatedFat, saltPer100g: e.salt)
            let entry = FoodEntry(food: tempFood, grams: e.grams, meal: meal, date: e.date)
            context.insert(entry)
        }

        // Ripristina logs
        for l in backup.logs {
            let log = DayLog(dateKey: l.dateKey)
            log.weight = l.weight
            log.steps = l.steps
            log.gymColor = GymColor(rawValue: l.gymColor) ?? .rest
            context.insert(log)
        }

        // Ripristina limiti
        if let l = backup.limits {
            let lim = AppLimits()
            lim.kcalTarget = l.kcalTarget; lim.proteinTarget = l.proteinTarget
            lim.carbsTarget = l.carbsTarget; lim.fatTarget = l.fatTarget
            lim.fiberTarget = l.fiberTarget; lim.sugarTarget = l.sugarTarget
            lim.saturatedFatTarget = l.saturatedFatTarget; lim.saltTarget = l.saltTarget
            lim.stepsTarget = l.stepsTarget; lim.weightTarget = l.weightTarget
            lim.startDate = l.startDate
            context.insert(lim)
        }

        // Ripristina sport
        for s in backup.sports ?? [] {
            context.insert(SportEntry(dayKey: s.dayKey, sportName: s.sportName,
                durationMinutes: s.durationMinutes, kcalBurned: s.kcalBurned))
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
            // Export
            HTCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Esporta backup")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Salva tutti i tuoi dati (alimenti, diario, peso, impostazioni) in un file JSON. Tienilo al sicuro prima di aggiornamenti importanti.")
                        .font(.system(size: 13)).foregroundColor(.muted)
                    Button {
                        doExport()
                    } label: {
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

            // Import
            HTCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(text: "Importa backup")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Ripristina i dati da un file JSON precedentemente esportato. Attenzione: i dati attuali verranno sostituiti.")
                        .font(.system(size: 13)).foregroundColor(.muted)
                    Button {
                        showImporter = true
                    } label: {
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
                if let data = pendingRestoreData {
                    doRestore(data)
                }
            }
            Button("Annulla", role: .cancel) {}
        }
        .alert(alertMsg, isPresented: $showAlert) {
            Button("OK") {}
        }
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

// MARK: - FileDocument per export

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
