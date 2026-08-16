import Foundation

// Verifica della logica di inserimento rapido e budget calorico.
// MealType è estratto da Models.swift a build time, così non diverge.

var failures = 0

func check(_ label: String, _ condition: Bool) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}

let day: TimeInterval = 86_400
let t0 = Date(timeIntervalSince1970: 1_770_000_000)

func entry(_ name: String, grams: Double, kcal: Double,
           daysAgo: Double, meal: MealType) -> FoodEntrySnapshot {
    FoodEntrySnapshot(foodName: name, grams: grams, kcal: kcal, protein: 0, carbs: 0,
                      fat: 0, fiber: 0, sugar: 0, saturatedFat: 0, salt: 0,
                      date: t0.addingTimeInterval(-daysAgo * day), meal: meal)
}

// ── 1. Alimenti recenti ───────────────────────────────────────────────────────

print("\n1. Recenti: deduplica, porzione più recente, filtro per pasto")

let history = [
    entry("Pollo",  grams: 200, kcal: 330, daysAgo: 1, meal: .lunch),
    entry("Pollo",  grams: 150, kcal: 248, daysAgo: 7, meal: .lunch),
    entry("Pasta",  grams: 100, kcal: 362, daysAgo: 2, meal: .lunch),
    entry("Avena",  grams:  80, kcal: 311, daysAgo: 1, meal: .breakfast),
    entry("Pollo",  grams: 120, kcal: 198, daysAgo: 3, meal: .dinner),
]

let lunch = makeRecentFoods(from: history, meal: .lunch)
check("un solo elemento per nome", lunch.count == 2)
check("ordinati dal più recente", lunch.first?.foodName == "Pollo")
check("porzione dell'uso più recente (200 g, non 150)", lunch.first?.grams == 200)
check("kcal coerenti con quella porzione", lunch.first?.kcal == 330)
check("conta gli usi nel pasto", lunch.first?.timesUsed == 2)
check("il pollo della cena non entra nel pranzo", lunch.first?.timesUsed != 3)
check("secondo elemento", lunch.last?.foodName == "Pasta")

let breakfast = makeRecentFoods(from: history, meal: .breakfast)
check("colazione isolata", breakfast.count == 1 && breakfast[0].foodName == "Avena")

let all = makeRecentFoods(from: history)
check("senza filtro accorpa tutti i pasti", all.count == 3)
check("pollo conteggiato 3 volte in totale", all.first(where: { $0.foodName == "Pollo" })?.timesUsed == 3)

// L'ordine di lettura non deve cambiare il risultato.
let shuffledSame = makeRecentFoods(from: history.reversed(), meal: .lunch)
check("indipendente dall'ordine di input", shuffledSame.first?.grams == 200)

check("limite rispettato", makeRecentFoods(from: history, limit: 2).count == 2)
check("storico vuoto → nessun suggerimento", makeRecentFoods(from: []).isEmpty)

// ── 2. Budget calorico ────────────────────────────────────────────────────────

print("\n2. Budget: residuo, sforamento, anteprima")

let under = CalorieBudget(consumed: 1200, target: 2000)
check("residuo corretto", under.remaining == 800)
check("non in eccesso", !under.isOver)
check("progresso 0.6", abs(under.progress - 0.6) < 0.0001)
check("etichetta residuo", under.shortLabel == "800 kcal rimaste")

let over = CalorieBudget(consumed: 2340, target: 2000)
check("eccesso rilevato", over.isOver)
check("etichetta eccesso", over.shortLabel == "+340 kcal sul target")
check("progresso oltre 1", over.progress > 1)

check("anteprima porzione che fa sforare", under.adding(900).isOver)
check("anteprima porzione che sta dentro", !under.adding(700).isOver)
check("anteprima non muta l'originale", under.consumed == 1200)
check("target assente → nessun panico", CalorieBudget(consumed: 500, target: 0).shortLabel == "—")

// Esattamente a target non è "oltre".
check("consumo pari al target non è sforamento", !CalorieBudget(consumed: 2000, target: 2000).isOver)

// ── 3. Ripartizione per pasto ─────────────────────────────────────────────────

print("\n3. Budget per pasto")

let noShares: [MealType: Double] = [:]
check("quote a zero → predefinite (pranzo 35%)",
      mealBudget(dailyTarget: 2000, meal: .lunch, shares: noShares) == 700)
check("quote a zero → predefinite (cena 30%)",
      mealBudget(dailyTarget: 2000, meal: .dinner, shares: noShares) == 600)

let defaultsSum = MealType.allCases.reduce(0.0) { $0 + $1.defaultBudgetShare }
check("le quote predefinite sommano a 1", abs(defaultsSum - 1.0) < 0.0001)

// Quote personalizzate che NON sommano a 100: devono essere normalizzate.
let custom: [MealType: Double] = [.breakfast: 20, .lunch: 20, .dinner: 20, .snack: 20]
check("quote uguali → un quarto ciascuna",
      abs(mealBudget(dailyTarget: 2000, meal: .dinner, shares: custom) - 500) < 0.0001)

let lopsided: [MealType: Double] = [.breakfast: 10, .lunch: 40, .dinner: 40, .snack: 10]
let sumAll = MealType.allCases.reduce(0.0) {
    $0 + mealBudget(dailyTarget: 2000, meal: $1, shares: lopsided)
}
check("la somma dei pasti resta il target giornaliero", abs(sumAll - 2000) < 0.0001)
check("pasto con quota maggiore ottiene di più",
      mealBudget(dailyTarget: 2000, meal: .lunch, shares: lopsided) == 800)

print("")
if failures == 0 { print("TUTTI I CONTROLLI SUPERATI") }
else { print("\(failures) CONTROLLI FALLITI"); exit(1) }
