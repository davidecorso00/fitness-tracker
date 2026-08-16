import AppIntents
import SwiftData
import Foundation

// Comandi esposti a Siri, Shortcuts e Spotlight.
//
// Girano nel processo dell'app, quindi possono aprire il database direttamente.
// Il contenitore è quello condiviso in FitnessAppApp: aprirne un secondo sullo
// stesso store porterebbe a scritture concorrenti.

// MARK: - Accesso al database

@MainActor
enum IntentStore {
    /// Contenitore dell'app, impostato all'avvio. Se un intent parte prima che
    /// l'app sia viva, il sistema la lancia comunque: qui si attende soltanto
    /// che il riferimento sia disponibile.
    static var container: ModelContainer?

    static func context() throws -> ModelContext {
        guard let container else { throw IntentError.databaseUnavailable }
        return container.mainContext
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case databaseUnavailable
    case noTarget

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .databaseUnavailable: return "Non riesco ad accedere ai dati dell'app."
        case .noTarget:            return "Imposta prima un obiettivo calorico nelle impostazioni."
        }
    }
}

// MARK: - Acqua

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra acqua"
    static var description = IntentDescription("Aggiunge acqua bevuta al diario di oggi.")

    @Parameter(title: "Quantità", default: .glass)
    var amount: WaterAmount

    static var parameterSummary: some ParameterSummary {
        Summary("Registra \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try IntentStore.context()
        let key = Date().dateKey
        context.insert(WaterEntry(dayKey: key, liters: amount.liters))
        try context.save()

        let all = (try? context.fetch(FetchDescriptor<WaterEntry>())) ?? []
        let today = all.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.liters }
        return .result(dialog: "Registrato. Oggi sei a \(String(format: "%.1f", today)) litri.")
    }
}

enum WaterAmount: String, AppEnum {
    case glass, smallBottle, bottle

    var liters: Double {
        switch self {
        case .glass:       return 0.2
        case .smallBottle: return 0.5
        case .bottle:      return 1.5
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Quantità d'acqua"
    static var caseDisplayRepresentations: [WaterAmount: DisplayRepresentation] = [
        .glass:       "un bicchiere",
        .smallBottle: "una bottiglietta",
        .bottle:      "una bottiglia",
    ]
}

// MARK: - Calorie rimaste

struct RemainingCaloriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Calorie rimaste"
    static var description = IntentDescription("Dice quante calorie restano per oggi.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try IntentStore.context()
        guard let limits = try context.fetch(FetchDescriptor<AppLimits>()).first,
              limits.kcalTarget > 0 else { throw IntentError.noTarget }

        let key = Date().dateKey
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let eaten = entries.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalSnapshot }
        let budget = CalorieBudget(consumed: eaten, target: limits.kcalTarget)

        return .result(dialog: budget.isOver
            ? "Hai superato il target di \(Int(eaten - limits.kcalTarget)) calorie."
            : "Ti restano \(Int(budget.remaining)) calorie su \(Int(limits.kcalTarget)).")
    }
}

// MARK: - Peso

struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Registra peso"
    static var description = IntentDescription("Salva il peso di oggi.")

    @Parameter(title: "Peso in kg", inclusiveRange: (20.0, 400.0))
    var kg: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Registra \(\.$kg) kg")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try IntentStore.context()
        let key = Date().dateKey

        let existing = try context.fetch(
            FetchDescriptor<DayLog>(predicate: #Predicate { $0.dateKey == key })).first
        let log = existing ?? DayLog(dateKey: key)
        if existing == nil { context.insert(log) }
        log.weight = kg
        try context.save()

        HealthExport.sendWeight(kg, on: Date())
        return .result(dialog: "Segnato: \(kg.clean) kg.")
    }
}

// MARK: - Ripeti un pasto

struct RepeatMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Ripeti un pasto di ieri"
    static var description = IntentDescription("Copia nel diario di oggi un pasto di ieri.")

    @Parameter(title: "Pasto", default: .lunch)
    var meal: MealChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Copia \(\.$meal) di ieri")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = try IntentStore.context()
        let yesterdayKey = Date().adding(days: -1).dateKey
        let target = meal.mealType

        let all = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let source = all.filter { $0.dayKey == yesterdayKey && $0.meal == target }
        guard !source.isEmpty else {
            return .result(dialog: "Ieri non avevi registrato niente per \(target.rawValue.lowercased()).")
        }

        let n = QuickLog.copyMeal(source, to: Date(), meal: target, context: context)
        let kcal = source.reduce(0.0) { $0 + $1.kcalSnapshot }
        return .result(dialog: "Copiati \(n) alimenti, \(Int(kcal)) calorie.")
    }
}

enum MealChoice: String, AppEnum {
    case breakfast, lunch, dinner, snack

    var mealType: MealType {
        switch self {
        case .breakfast: return .breakfast
        case .lunch:     return .lunch
        case .dinner:    return .dinner
        case .snack:     return .snack
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pasto"
    static var caseDisplayRepresentations: [MealChoice: DisplayRepresentation] = [
        .breakfast: "la colazione",
        .lunch:     "il pranzo",
        .dinner:    "la cena",
        .snack:     "gli snack",
    ]
}

// MARK: - Frasi pronte per Siri

struct FitnessShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Registra acqua su \(.applicationName)",
                "Aggiungi un bicchiere d'acqua su \(.applicationName)",
                "Ho bevuto su \(.applicationName)",
            ],
            shortTitle: "Registra acqua",
            systemImageName: "drop.fill")

        AppShortcut(
            intent: RemainingCaloriesIntent(),
            phrases: [
                "Calorie rimaste su \(.applicationName)",
                "Quante calorie mi restano su \(.applicationName)",
            ],
            shortTitle: "Calorie rimaste",
            systemImageName: "flame.fill")

        AppShortcut(
            intent: LogWeightIntent(),
            phrases: ["Registra il peso su \(.applicationName)"],
            shortTitle: "Registra peso",
            systemImageName: "scalemass.fill")

        AppShortcut(
            intent: RepeatMealIntent(),
            phrases: ["Ripeti un pasto su \(.applicationName)"],
            shortTitle: "Ripeti un pasto",
            systemImageName: "arrow.turn.down.left")
    }
}
